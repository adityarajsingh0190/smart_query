import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../models/query_defaults.dart';
import '../models/query_options.dart';
import '../observers/connectivity_observer.dart';
import '../widgets/query_client_provider.dart';
import 'query_cache.dart';

/// The central entry point for all query and cache operations.
///
/// Holds the [QueryCache] and provides methods for prefetching,
/// invalidating, and manually setting query data.
///
/// Access via [QueryClient.of] within the widget tree after wrapping
/// your app with [QueryClientProvider].
class QueryClient {
  /// Creates a query client.
  QueryClient({
    QueryDefaults? defaultOptions,
    ConnectivityObserver? connectivityObserver,
  })  : _defaultOptions = defaultOptions ?? const QueryDefaults(),
        _connectivityObserver = connectivityObserver {
    _setupConnectivityListener();
  }

  final QueryDefaults _defaultOptions;
  final ConnectivityObserver? _connectivityObserver;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  /// The underlying query cache.
  final QueryCache cache = QueryCache();

  /// The global default options for all queries.
  QueryDefaults get defaultOptions => _defaultOptions;

  /// Retrieves the [QueryClient] from the nearest [QueryClientProvider].
  static QueryClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<QueryClientInherited>();
    assert(
      provider != null,
      'QueryClientProvider not found. Wrap your app with QueryClientProvider.',
    );
    return provider!.client;
  }

  // ─── Query manipulation ───

  /// Prefetches a query, populating the cache before any widget needs it.
  Future<void> prefetchQuery<T>(
    List<dynamic> key,
    QueryFetcher<T> fetcher, {
    Duration? staleTime,
    Duration? cacheTime,
  }) async {
    final options = QueryOptions<T>(
      key: key,
      fetcher: fetcher,
      staleTime: staleTime ?? _defaultOptions.staleTime,
      cacheTime: cacheTime ?? _defaultOptions.cacheTime,
    );
    final query = cache.getOrCreate<T>(key, options);
    await query.fetch();
  }

  /// Returns the current cached data for [key], or `null` if not cached.
  T? getQueryData<T>(List<dynamic> key) {
    final query = cache.get<T>(key);
    return query?.data;
  }

  /// Sets query data directly, bypassing the fetcher.
  ///
  /// Accepts either a direct value of type [T] or an updater function
  /// `T Function(T? old)`.
  void setQueryData<T>(List<dynamic> key, dynamic updaterOrValue) {
    final query = cache.get<T>(key);
    if (query == null) {
      final options = QueryOptions<T>(
        key: key,
        fetcher: () => throw StateError(
          'No fetcher defined. This query was created via setQueryData.',
        ),
        staleTime: _defaultOptions.staleTime,
        cacheTime: _defaultOptions.cacheTime,
      );
      final newQuery = cache.getOrCreate<T>(key, options);
      final T data;
      if (updaterOrValue is T Function(T?)) {
        data = updaterOrValue(null);
      } else {
        data = updaterOrValue as T;
      }
      newQuery.setData(data);
      return;
    }

    final T newData;
    if (updaterOrValue is T Function(T?)) {
      newData = updaterOrValue(query.data);
    } else {
      newData = updaterOrValue as T;
    }
    query.setData(newData);
  }

  /// Invalidates queries matching [key] (hierarchical prefix match).
  ///
  /// Pass `null` to invalidate all queries.
  Future<void> invalidateQueries([List<dynamic>? key]) async {
    if (key == null) {
      for (final q in cache.queries.values.toList()) {
        q.invalidate();
      }
      return;
    }
    final queries = cache.getQueriesByPrefix(key);
    for (final q in queries) {
      q.invalidate();
    }
  }

  /// Cancels in-flight fetches for queries matching [key].
  Future<void> cancelQueries([List<dynamic>? key]) async {
    final queries = key != null
        ? cache.getQueriesByPrefix(key)
        : cache.queries.values.toList();
    for (final q in queries) {
      q.cancel();
    }
  }

  /// Removes queries matching [key] from cache entirely.
  void removeQueries([List<dynamic>? key]) {
    if (key == null) {
      cache.clear();
      return;
    }
    final queries = cache.getQueriesByPrefix(key);
    for (final q in queries) {
      cache.remove(q.key);
    }
  }

  /// Clears the entire cache. Used for logout flows.
  void clear() {
    cache.clear();
  }

  /// Refetches all stale queries that have active observers.
  @internal
  Future<void> refetchStaleActiveQueries({
    bool respectRefetchOnWindowFocus = false,
    bool respectRefetchOnReconnect = false,
  }) async {
    await cache.refetchStaleQueries();
  }

  /// Disposes the client, cleaning up all resources.
  void dispose() {
    _connectivitySubscription?.cancel();
    cache.dispose();
  }

  void _setupConnectivityListener() {
    if (_connectivityObserver == null) return;
    _connectivitySubscription =
        _connectivityObserver!.onStatusChanged.listen((status) {
      if (status == ConnectivityStatus.online) {
        refetchStaleActiveQueries(respectRefetchOnReconnect: true);
      }
    });
  }
}
