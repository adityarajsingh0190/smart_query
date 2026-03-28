import 'dart:async';

import 'package:meta/meta.dart';

import '../models/query_options.dart';
import '../models/query_result.dart';
import '../models/query_status.dart';
import 'query_cache.dart';

/// An observable state machine that manages a single query's lifecycle.
///
/// [Query] handles fetching, caching, retries, deduplication, staleness,
/// and observer management. Multiple widgets subscribe to the same [Query]
/// via its broadcast [stream].
class Query<T> {
  /// Creates a new query.
  Query({
    required this.key,
    required QueryOptions<T> options,
    required QueryCache cache,
  })  : _options = options,
        _cache = cache {
    // If initialData is provided, start in success state immediately.
    if (_options.initialData != null) {
      _data = _options.initialData;
      _status = QueryStatus.success;
      _dataUpdatedAt = DateTime.now();
    }
  }

  /// The query key.
  final List<dynamic> key;

  /// The parent cache that owns this query.
  final QueryCache _cache;

  // ─── Mutable options (updated when a new observer provides different ones)
  QueryOptions<T> _options;

  // ─── Internal state ───
  T? _data;
  Object? _error;
  StackTrace? _errorStackTrace;
  QueryStatus _status = QueryStatus.idle;
  DateTime? _dataUpdatedAt;
  DateTime? _errorUpdatedAt;

  // ─── Deduplication ───
  Future<void>? _activeFetch;

  // ─── Timers ───
  Timer? _cacheEvictionTimer;
  Timer? _refetchIntervalTimer;
  Timer? _retryTimer;

  // ─── Retry tracking ───
  int _retryCount = 0;

  // ─── Observer management ───
  int _observerCount = 0;

  // ─── Lifecycle flags ───
  bool _disposed = false;

  // ─── Fetch ID for race condition prevention ───
  int _fetchId = 0;

  // ─── Stream ───
  final StreamController<QueryResult<T>> _controller =
      StreamController<QueryResult<T>>.broadcast();

  /// Stream of query result updates. Multiple widgets can listen.
  Stream<QueryResult<T>> get stream => _controller.stream;

  /// The current options for this query.
  QueryOptions<T> get options => _options;

  /// The number of widgets currently observing this query.
  int get observerCount => _observerCount;

  /// The current data, if available.
  T? get data => _data;

  /// The current status.
  QueryStatus get status => _status;

  /// When data was last successfully fetched.
  DateTime? get dataUpdatedAt => _dataUpdatedAt;

  /// Whether the query's data is stale and needs a refetch.
  bool get isStale {
    if (_dataUpdatedAt == null) return true;
    if (_options.staleTime == Duration.zero) return true;
    return DateTime.now().difference(_dataUpdatedAt!) > _options.staleTime;
  }

  /// Whether this query is currently fetching (has an active in-flight request).
  bool get isFetching => _activeFetch != null;

  /// Returns the current state as a [QueryResult].
  QueryResult<T> get currentResult => QueryResult<T>(
        data: _data,
        error: _error,
        errorStackTrace: _errorStackTrace,
        status: _status,
        dataUpdatedAt: _dataUpdatedAt,
        errorUpdatedAt: _errorUpdatedAt,
        refetch: () => fetch(force: true),
      );

  // ─── Options management ───

  /// Updates the options for this query. Called when a new observer
  /// subscribes with potentially different options.
  @internal
  void updateOptions(QueryOptions<T> options) {
    _options = options;
  }

  // ─── Observer management ───

  /// Registers a new observer (widget). Cancels pending cache eviction.
  void addObserver() {
    _observerCount++;
    _cacheEvictionTimer?.cancel();
    _cacheEvictionTimer = null;
    _startRefetchIntervalIfNeeded();
  }

  /// Unregisters an observer. If no observers remain, starts the cache
  /// eviction countdown and stops polling.
  void removeObserver() {
    _observerCount--;
    if (_observerCount <= 0) {
      _observerCount = 0;
      _stopRefetchInterval();
      _startEvictionTimer();
    }
  }

  // ─── Fetching ───

  /// Fetches data for this query.
  ///
  /// If [force] is `true`, fetches regardless of staleness and ignores
  /// any in-flight request (cancels it first).
  ///
  /// Deduplication: if a fetch is already in progress and [force] is
  /// `false`, the same future is returned.
  Future<void> fetch({bool force = false}) async {
    if (_disposed) return;
    if (!_options.enabled) return;

    // Deduplication — reuse the in-flight request.
    if (_activeFetch != null && !force) {
      return _activeFetch!;
    }

    // Don't refetch if data is fresh.
    if (!isStale && !force && _data != null) return;

    // Cancel any previous in-flight request if forcing.
    if (force && _activeFetch != null) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }

    final fetchFuture = _doFetch();
    _activeFetch = fetchFuture;
    try {
      await fetchFuture;
    } finally {
      // Only clear if this is still the active fetch (not superseded by a
      // forced fetch that started while we were awaiting).
      if (_activeFetch == fetchFuture) {
        _activeFetch = null;
      }
    }
  }

  Future<void> _doFetch() async {
    if (_disposed) return;

    // Increment fetch ID for race condition detection.
    final currentFetchId = ++_fetchId;
    _retryCount = 0;

    // Set status: loading if no data, refreshing if we have stale data.
    _status = (_data != null) ? QueryStatus.refreshing : QueryStatus.loading;
    _emit();

    await _attemptFetch(currentFetchId);
  }

  Future<void> _attemptFetch(int fetchId) async {
    if (_disposed) return;

    try {
      var result = await _options.fetcher();
      if (_disposed) return;
      if (_fetchId != fetchId) {
        return; // Superseded by newer fetch / setQueryData.
      }

      // Apply select transform if provided.
      if (_options.select != null) {
        result = _options.select!(result);
      }

      _data = result;
      _status = QueryStatus.success;
      _dataUpdatedAt = DateTime.now();
      _error = null;
      _errorStackTrace = null;
      _emit();

      // Callbacks.
      _options.onSuccess?.call(result, key);
      _options.onSettled?.call(result, null);
    } catch (e, st) {
      if (_disposed) return;
      if (_fetchId != fetchId) return;

      // Check if we should retry.
      final shouldRetry =
          _retryCount < _options.retry && (_options.retryWhen?.call(e) ?? true);

      if (shouldRetry) {
        _retryCount++;
        final delay = _options.retryDelay(_retryCount - 1);
        _retryTimer?.cancel();
        _retryTimer = Timer(delay, () {
          if (!_disposed && _fetchId == fetchId) {
            _attemptFetch(fetchId);
          }
        });
        return;
      }

      // All retries exhausted — set error state.
      _error = e;
      _errorStackTrace = st;
      _status = QueryStatus.error;
      _errorUpdatedAt = DateTime.now();
      _emit();

      _options.onError?.call(e, st, key);
      _options.onSettled?.call(_data, e);
    }
  }

  // ─── Manual data manipulation ───

  /// Sets the query data directly, bypassing the fetcher.
  ///
  /// Used for optimistic updates. Increments [_fetchId] to prevent any
  /// in-flight fetch from overwriting this value.
  void setData(T data) {
    if (_disposed) return;
    _fetchId++; // Invalidate any in-flight fetch.
    _data = data;
    _status = QueryStatus.success;
    _dataUpdatedAt = DateTime.now();
    _error = null;
    _errorStackTrace = null;
    _emit();
  }

  /// Marks this query as stale, so the next observation triggers a refetch.
  void invalidate() {
    // Setting dataUpdatedAt to null makes isStale return true.
    _dataUpdatedAt = _dataUpdatedAt
        ?.subtract(_options.staleTime + const Duration(seconds: 1));
    // If there are active observers, immediately refetch.
    if (_observerCount > 0) {
      fetch(force: true);
    }
  }

  // ─── Cancellation ───

  /// Cancels any in-flight fetch and pending retry timers.
  void cancel() {
    _fetchId++; // Invalidate the current fetch.
    _activeFetch = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ─── Disposal ───

  /// Disposes this query, cancelling all timers and closing the stream.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _activeFetch = null;
    _cacheEvictionTimer?.cancel();
    _refetchIntervalTimer?.cancel();
    _retryTimer?.cancel();
    _cacheEvictionTimer = null;
    _refetchIntervalTimer = null;
    _retryTimer = null;
    _controller.close();
  }

  // ─── Private helpers ───

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(currentResult);
    }
  }

  void _startEvictionTimer() {
    _cacheEvictionTimer?.cancel();
    _cacheEvictionTimer = Timer(_options.cacheTime, () {
      _cache.remove(key);
    });
  }

  void _startRefetchIntervalIfNeeded() {
    if (_options.refetchInterval == null) return;
    if (_refetchIntervalTimer != null) return;
    _refetchIntervalTimer = Timer.periodic(_options.refetchInterval!, (_) {
      if (_observerCount > 0 && !_disposed) {
        fetch(force: true);
      }
    });
  }

  void _stopRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }
}
