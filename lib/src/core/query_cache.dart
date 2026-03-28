import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'query.dart';
import '../models/query_options.dart';

/// Events emitted by [QueryCache] for devtools and debugging.
enum CacheEventType {
  /// A query was added to the cache.
  added,

  /// A query's data was updated.
  updated,

  /// A query was removed from the cache.
  removed,
}

/// An event emitted by [QueryCache] when the cache changes.
class CacheEvent {
  /// Creates a cache event.
  const CacheEvent({
    required this.type,
    required this.key,
  });

  /// The type of cache event.
  final CacheEventType type;

  /// The query key that was affected.
  final List<dynamic> key;

  @override
  String toString() => 'CacheEvent($type, key: $key)';
}

/// Central in-memory store for all query state.
///
/// Never stores raw data — stores [Query] objects which own the data AND
/// the broadcast stream. Multiple widgets subscribing to the same key
/// share ONE stream through the same [Query] instance.
class QueryCache {
  /// Creates a new query cache.
  QueryCache();

  final Map<String, Query<dynamic>> _queries = {};
  final StreamController<CacheEvent> _eventController =
      StreamController<CacheEvent>.broadcast();

  /// Stream of cache lifecycle events. Useful for devtools.
  Stream<CacheEvent> get events => _eventController.stream;

  /// All currently-cached queries (read-only view).
  Map<String, Query<dynamic>> get queries => Map.unmodifiable(_queries);

  /// Returns the existing [Query] for [key], or creates a new one using
  /// the supplied [options].
  ///
  /// If a query already exists for this key, the existing instance is
  /// returned and the caller shares the same stream.
  Query<T> getOrCreate<T>(List<dynamic> key, QueryOptions<T> options) {
    final cacheKey = serializeKey(key);
    final existing = _queries[cacheKey];
    if (existing != null) {
      // Update options on the existing query so latest settings are used.
      final typed = existing as Query<T>;
      typed.updateOptions(options);
      return typed;
    }
    final query = Query<T>(key: key, options: options, cache: this);
    _queries[cacheKey] = query;
    if (!_eventController.isClosed) {
      _eventController.add(CacheEvent(type: CacheEventType.added, key: key));
    }
    return query;
  }

  /// Returns the cached [Query] for [key], or `null` if not found.
  Query<T>? get<T>(List<dynamic> key) {
    final cacheKey = serializeKey(key);
    final query = _queries[cacheKey];
    if (query == null) return null;
    return query as Query<T>;
  }

  /// Removes a query from the cache and disposes it.
  void remove(List<dynamic> key) {
    final cacheKey = serializeKey(key);
    final query = _queries.remove(cacheKey);
    if (query != null) {
      query.dispose();
      if (!_eventController.isClosed) {
        _eventController
            .add(CacheEvent(type: CacheEventType.removed, key: key));
      }
    }
  }

  /// Removes ALL queries from the cache and disposes them.
  void clear() {
    final allQueries = _queries.values.toList();
    _queries.clear();
    for (final query in allQueries) {
      query.dispose();
    }
  }

  /// Returns all queries whose keys start with [keyPrefix].
  ///
  /// This enables hierarchical invalidation:
  /// `getQueriesByPrefix(['user'])` matches `['user', 1]`, `['user', 2]`, etc.
  List<Query<dynamic>> getQueriesByPrefix(List<dynamic> keyPrefix) {
    final prefixStr = serializeKey(keyPrefix);
    // A prefix of '["user"]' should match '["user",1]', '["user","posts"]', etc.
    // We strip the trailing ']' and check startsWith on the remaining prefix.
    final prefixWithoutClose = prefixStr.substring(0, prefixStr.length - 1);

    return _queries.entries
        .where((entry) {
          if (entry.key == prefixStr) return true;
          // Match if the stored key starts with the prefix elements followed
          // by a comma (meaning more elements follow).
          return entry.key.startsWith('$prefixWithoutClose,');
        })
        .map((entry) => entry.value)
        .toList();
  }

  /// Returns all queries that have at least one active observer.
  List<Query<dynamic>> getActiveQueries() {
    return _queries.values.where((query) => query.observerCount > 0).toList();
  }

  /// Triggers a refetch of all stale queries that have active observers.
  Future<void> refetchStaleQueries() async {
    final activeStale =
        _queries.values.where((q) => q.observerCount > 0 && q.isStale).toList();

    // Stagger refetches by 10ms to prevent thundering herd.
    final futures = <Future<void>>[];
    for (var i = 0; i < activeStale.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      futures.add(activeStale[i].fetch(force: true));
    }
    await Future.wait(futures);
  }

  /// Disposes the cache, closing the event stream.
  void dispose() {
    clear();
    _eventController.close();
  }

  // ─── Key serialization ───

  /// Serializes a query key to a deterministic string.
  ///
  /// Map keys are sorted alphabetically to ensure
  /// `{'a': 1, 'b': 2}` and `{'b': 2, 'a': 1}` produce the same key.
  static String serializeKey(List<dynamic> key) {
    return jsonEncode(_normalizeKey(key));
  }

  static dynamic _normalizeKey(dynamic value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), _normalizeKey(v))),
      );
      return sorted;
    }
    if (value is List) {
      return value.map(_normalizeKey).toList();
    }
    return value;
  }
}
