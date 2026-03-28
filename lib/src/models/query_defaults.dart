import 'query_options.dart';

/// Global default options for all queries managed by a [QueryClient].
///
/// These defaults are used when a specific query does not override them.
class QueryDefaults {
  /// Creates global default options for queries.
  const QueryDefaults({
    this.staleTime = Duration.zero,
    this.cacheTime = const Duration(minutes: 5),
    this.retry = 3,
    this.retryDelay,
    this.retryWhen,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchInterval,
  });

  /// Default stale time for all queries.
  final Duration staleTime;

  /// Default cache eviction time for all queries.
  final Duration cacheTime;

  /// Default number of retries for all queries.
  final int retry;

  /// Default retry delay function.
  final RetryDelayFn? retryDelay;

  /// Default retry condition predicate.
  final RetryWhenFn? retryWhen;

  /// Whether to refetch stale queries on app resume by default.
  final bool refetchOnWindowFocus;

  /// Whether to refetch stale queries on reconnect by default.
  final bool refetchOnReconnect;

  /// Default polling interval for all queries. `null` means no polling.
  final Duration? refetchInterval;
}
