import 'dart:async';
import 'dart:math';

/// Type alias for a query fetcher function.
typedef QueryFetcher<T> = Future<T> Function();

/// Type alias for a paginated query fetcher function.
typedef PagedQueryFetcher<T, TPageParam> = Future<T> Function(
    TPageParam pageParam);

/// Type alias for a mutation function.
typedef MutatorFn<TData, TVariables> = Future<TData> Function(
    TVariables variables);

/// Type alias for retry delay calculation.
typedef RetryDelayFn = Duration Function(int attemptIndex);

/// Type alias for conditional retry.
typedef RetryWhenFn = bool Function(Object error);

/// Type alias for the onMutate callback.
typedef OnMutateFn<TVariables> = FutureOr<dynamic> Function(
    TVariables variables);

/// Type alias for the onSuccess callback of a mutation.
typedef OnMutationSuccessFn<TData, TVariables> = FutureOr<void> Function(
    TData data, TVariables variables, dynamic context);

/// Type alias for the onError callback of a mutation.
typedef OnMutationErrorFn<TVariables> = FutureOr<void> Function(
    Object error, TVariables variables, dynamic context);

/// Type alias for the onSettled callback of a mutation.
typedef OnMutationSettledFn<TData, TVariables> = FutureOr<void> Function(
    TData? data, Object? error, TVariables variables, dynamic context);

/// Default retry delay using exponential backoff with jitter.
Duration defaultRetryDelay(int attemptIndex) {
  final base = Duration(milliseconds: 1000 * pow(2, attemptIndex).toInt());
  final jitter = Duration(milliseconds: Random().nextInt(500));
  return base + jitter;
}

/// Configuration options for a query.
///
/// Controls caching behaviour, retry logic, and lifecycle callbacks.
class QueryOptions<T> {
  /// Creates query options.
  ///
  /// [key] identifies this query in the cache.
  /// [fetcher] is the async function that retrieves data.
  QueryOptions({
    required this.key,
    required this.fetcher,
    this.staleTime = Duration.zero,
    this.cacheTime = const Duration(minutes: 5),
    this.enabled = true,
    this.retry = 3,
    RetryDelayFn? retryDelay,
    this.retryWhen,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.refetchInterval,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.initialData,
    this.select,
    this.keepPreviousData = false,
  }) : retryDelay = retryDelay ?? defaultRetryDelay;

  /// The query key — a hierarchical identifier for this query.
  final List<dynamic> key;

  /// The function that fetches data.
  final QueryFetcher<T> fetcher;

  /// How long data is considered fresh after fetching.
  /// During this window, no refetch happens even if the widget rebuilds.
  /// Default: [Duration.zero] (immediately stale).
  final Duration staleTime;

  /// How long unused data stays in cache after all observers leave.
  /// Default: 5 minutes.
  final Duration cacheTime;

  /// Whether the query is enabled. Set to `false` for dependent queries.
  final bool enabled;

  /// Number of retries on failure. Default: 3. Set to 0 to disable.
  final int retry;

  /// Delay between retry attempts. Default: exponential backoff with jitter.
  final RetryDelayFn retryDelay;

  /// Optional predicate to decide whether to retry a specific error.
  /// Return `false` to skip retries for this error type.
  final RetryWhenFn? retryWhen;

  /// Whether to refetch stale data when the app resumes from background.
  final bool refetchOnWindowFocus;

  /// Whether to refetch stale data when network connectivity is restored.
  final bool refetchOnReconnect;

  /// If set, the query will refetch at this interval while it has observers.
  final Duration? refetchInterval;

  /// Called when the query fetches data successfully.
  final void Function(T data, List<dynamic> key)? onSuccess;

  /// Called when the query encounters an error after exhausting retries.
  final void Function(Object error, StackTrace stackTrace, List<dynamic> key)?
      onError;

  /// Called after every fetch attempt completes (success or error).
  final void Function(T? data, Object? error)? onSettled;

  /// If set, the query starts in success state with this data immediately.
  /// The fetcher is still called if the data is stale.
  final T? initialData;

  /// Transform function applied to fetched data before caching.
  final T Function(T data)? select;

  /// When `true`, the previous data is shown while a new key's data loads.
  final bool keepPreviousData;

  /// Creates a copy of these options with the given overrides.
  QueryOptions<T> copyWith({
    List<dynamic>? key,
    QueryFetcher<T>? fetcher,
    Duration? staleTime,
    Duration? cacheTime,
    bool? enabled,
    int? retry,
    RetryDelayFn? retryDelay,
    RetryWhenFn? retryWhen,
    bool? refetchOnWindowFocus,
    bool? refetchOnReconnect,
    Duration? refetchInterval,
    void Function(T data, List<dynamic> key)? onSuccess,
    void Function(Object error, StackTrace stackTrace, List<dynamic> key)?
        onError,
    void Function(T? data, Object? error)? onSettled,
    T? initialData,
    T Function(T data)? select,
    bool? keepPreviousData,
  }) {
    return QueryOptions<T>(
      key: key ?? this.key,
      fetcher: fetcher ?? this.fetcher,
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      enabled: enabled ?? this.enabled,
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      retryWhen: retryWhen ?? this.retryWhen,
      refetchOnWindowFocus: refetchOnWindowFocus ?? this.refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect ?? this.refetchOnReconnect,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      onSettled: onSettled ?? this.onSettled,
      initialData: initialData ?? this.initialData,
      select: select ?? this.select,
      keepPreviousData: keepPreviousData ?? this.keepPreviousData,
    );
  }
}

/// Configuration options for a mutation.
class MutationOptions<TData, TVariables> {
  /// Creates mutation options.
  MutationOptions({
    required this.mutator,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.retry = 0,
    RetryDelayFn? retryDelay,
    this.retryWhen,
  }) : retryDelay = retryDelay ?? defaultRetryDelay;

  /// The function that performs the mutation.
  final MutatorFn<TData, TVariables> mutator;

  /// Called before the mutation runs. Return a context value for rollback.
  final OnMutateFn<TVariables>? onMutate;

  /// Called when the mutation succeeds.
  final OnMutationSuccessFn<TData, TVariables>? onSuccess;

  /// Called when the mutation fails.
  final OnMutationErrorFn<TVariables>? onError;

  /// Called after the mutation completes (success or failure).
  final OnMutationSettledFn<TData, TVariables>? onSettled;

  /// Number of retries on failure. Default: 0 (mutations do not retry).
  final int retry;

  /// Delay between retry attempts.
  final RetryDelayFn retryDelay;

  /// Optional predicate to decide whether to retry a specific error.
  final RetryWhenFn? retryWhen;
}
