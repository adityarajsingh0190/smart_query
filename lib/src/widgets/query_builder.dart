import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/query.dart';
import '../core/query_cache.dart';
import '../core/query_client.dart';
import '../models/query_options.dart';
import '../models/query_result.dart';

/// A widget that fetches and caches data, rebuilding when the query state changes.
///
/// This is the primary way to use `smart_query` without `flutter_hooks`.
///
/// ```dart
/// QueryBuilder<User>(
///   queryKey: ['user', userId],
///   fetcher: () => api.getUser(userId),
///   builder: (context, result) {
///     if (result.isLoading) return CircularProgressIndicator();
///     if (result.isError) return Text('Error: ${result.error}');
///     return Text(result.data!.name);
///   },
/// )
/// ```
class QueryBuilder<T> extends StatefulWidget {
  /// Creates a [QueryBuilder].
  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.builder,
    this.staleTime,
    this.cacheTime,
    this.enabled = true,
    this.retry,
    this.retryDelay,
    this.retryWhen,
    this.refetchOnWindowFocus,
    this.refetchOnReconnect,
    this.refetchInterval,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.initialData,
    this.select,
    this.keepPreviousData = false,
  });

  /// The query key for cache lookup.
  final List<dynamic> queryKey;

  /// The async function that fetches data.
  final QueryFetcher<T> fetcher;

  /// Builder function called with the query result.
  final Widget Function(BuildContext context, QueryResult<T> result) builder;

  /// How long data is considered fresh.
  final Duration? staleTime;

  /// How long unused data stays in cache.
  final Duration? cacheTime;

  /// Whether the query is enabled.
  final bool enabled;

  /// Number of retries on failure.
  final int? retry;

  /// Delay between retries.
  final RetryDelayFn? retryDelay;

  /// Predicate for conditional retry.
  final RetryWhenFn? retryWhen;

  /// Whether to refetch on app resume.
  final bool? refetchOnWindowFocus;

  /// Whether to refetch on reconnect.
  final bool? refetchOnReconnect;

  /// Polling interval.
  final Duration? refetchInterval;

  /// Success callback.
  final void Function(T data, List<dynamic> key)? onSuccess;

  /// Error callback.
  final void Function(Object error, StackTrace st, List<dynamic> key)? onError;

  /// Settled callback.
  final void Function(T? data, Object? error)? onSettled;

  /// Initial data to show before first fetch.
  final T? initialData;

  /// Transform function applied to fetched data.
  final T Function(T data)? select;

  /// Whether to show previous data while new key loads.
  final bool keepPreviousData;

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  late QueryClient _client;
  Query<T>? _query;
  StreamSubscription<QueryResult<T>>? _subscription;
  QueryResult<T>? _result;
  QueryResult<T>? _previousResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = QueryClient.of(context);
    if (_query == null) {
      _subscribeToQuery();
    }
  }

  @override
  void didUpdateWidget(QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKey = QueryCache.serializeKey(oldWidget.queryKey);
    final newKey = QueryCache.serializeKey(widget.queryKey);

    if (oldKey != newKey || oldWidget.enabled != widget.enabled) {
      if (widget.keepPreviousData && _result?.data != null) {
        _previousResult = _result;
      }
      _unsubscribe();
      _subscribeToQuery();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribeToQuery() {
    final defaults = _client.defaultOptions;
    final options = QueryOptions<T>(
      key: widget.queryKey,
      fetcher: widget.fetcher,
      staleTime: widget.staleTime ?? defaults.staleTime,
      cacheTime: widget.cacheTime ?? defaults.cacheTime,
      enabled: widget.enabled,
      retry: widget.retry ?? defaults.retry,
      retryDelay: widget.retryDelay ?? defaults.retryDelay,
      retryWhen: widget.retryWhen ?? defaults.retryWhen,
      refetchOnWindowFocus:
          widget.refetchOnWindowFocus ?? defaults.refetchOnWindowFocus,
      refetchOnReconnect:
          widget.refetchOnReconnect ?? defaults.refetchOnReconnect,
      refetchInterval: widget.refetchInterval ?? defaults.refetchInterval,
      onSuccess: widget.onSuccess,
      onError: widget.onError,
      onSettled: widget.onSettled,
      initialData: widget.initialData,
      select: widget.select,
      keepPreviousData: widget.keepPreviousData,
    );

    _query = _client.cache.getOrCreate<T>(widget.queryKey, options);
    _query!.addObserver();

    _result = _query!.currentResult;

    // keepPreviousData: show old data while new key loads.
    if (widget.keepPreviousData &&
        _result!.data == null &&
        _previousResult?.data != null) {
      _result = _result!.copyWith(
        data: _previousResult!.data,
        isPreviousData: true,
      );
    }

    _subscription = _query!.stream.listen((newResult) {
      if (!mounted) return;
      setState(() {
        if (widget.keepPreviousData &&
            newResult.data == null &&
            _previousResult?.data != null) {
          _result = newResult.copyWith(
            data: _previousResult!.data,
            isPreviousData: true,
          );
        } else {
          _result = newResult;
          if (newResult.data != null) {
            _previousResult = null;
          }
        }
      });
    });

    if (widget.enabled) {
      _query!.fetch();
    }
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _query?.removeObserver();
    _query = null;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result ??
        QueryResult<T>.idle(
          refetch: () => _query?.fetch(force: true),
        );
    return widget.builder(context, result);
  }
}
