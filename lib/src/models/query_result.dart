import 'package:flutter/foundation.dart';

import 'query_status.dart';

/// Immutable result of a query, containing data, error, and status information.
///
/// Widgets use this to decide what to render (loading, error, or data).
class QueryResult<T> {
  /// Creates a query result.
  const QueryResult({
    this.data,
    this.error,
    this.errorStackTrace,
    required this.status,
    this.isPreviousData = false,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
    required this.refetch,
  });

  /// Creates an idle result (query not yet triggered).
  factory QueryResult.idle({required VoidCallback refetch}) {
    return QueryResult<T>(
      status: QueryStatus.idle,
      refetch: refetch,
    );
  }

  /// Creates a loading result.
  factory QueryResult.loading({required VoidCallback refetch}) {
    return QueryResult<T>(
      status: QueryStatus.loading,
      refetch: refetch,
    );
  }

  /// The cached data, or `null` if not yet fetched.
  final T? data;

  /// The error from the last failed fetch, or `null`.
  final Object? error;

  /// Stack trace from the last failed fetch.
  final StackTrace? errorStackTrace;

  /// The current status of the query.
  final QueryStatus status;

  /// `true` when [keepPreviousData] is active and showing data from a
  /// previously-subscribed key while the new key loads.
  final bool isPreviousData;

  /// When data was last successfully fetched.
  final DateTime? dataUpdatedAt;

  /// When an error was last received.
  final DateTime? errorUpdatedAt;

  /// Triggers a manual refetch.
  final VoidCallback refetch;

  // ── Computed convenience getters ──

  /// Whether this is the initial load with no data yet.
  bool get isLoading => status == QueryStatus.loading;

  /// Whether data exists and a background refresh is in progress.
  bool get isRefreshing => status == QueryStatus.refreshing;

  /// Whether any fetch is in progress (initial or background).
  bool get isFetching => isLoading || isRefreshing;

  /// Whether data was loaded successfully.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the last fetch resulted in an error.
  bool get isError => status == QueryStatus.error;

  /// Whether the query is idle (disabled or never triggered).
  bool get isIdle => status == QueryStatus.idle;

  /// Creates a copy with the given overrides.
  QueryResult<T> copyWith({
    T? data,
    Object? error,
    StackTrace? errorStackTrace,
    QueryStatus? status,
    bool? isPreviousData,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
    VoidCallback? refetch,
    bool clearError = false,
    bool clearData = false,
  }) {
    return QueryResult<T>(
      data: clearData ? null : (data ?? this.data),
      error: clearError ? null : (error ?? this.error),
      errorStackTrace:
          clearError ? null : (errorStackTrace ?? this.errorStackTrace),
      status: status ?? this.status,
      isPreviousData: isPreviousData ?? this.isPreviousData,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      refetch: refetch ?? this.refetch,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryResult<T> &&
        other.data == data &&
        other.error == error &&
        other.status == status &&
        other.isPreviousData == isPreviousData &&
        other.dataUpdatedAt == dataUpdatedAt &&
        other.errorUpdatedAt == errorUpdatedAt;
  }

  @override
  int get hashCode => Object.hash(
        data,
        error,
        status,
        isPreviousData,
        dataUpdatedAt,
        errorUpdatedAt,
      );

  @override
  String toString() {
    return 'QueryResult<$T>('
        'status: $status, '
        'data: $data, '
        'error: $error, '
        'isPreviousData: $isPreviousData, '
        'dataUpdatedAt: $dataUpdatedAt, '
        'errorUpdatedAt: $errorUpdatedAt)';
  }
}

/// Immutable result of a mutation.
class MutationResult<TData, TVariables> {
  /// Creates a mutation result.
  const MutationResult({
    required this.status,
    this.data,
    this.error,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
  });

  /// The current status of the mutation.
  final MutationStatus status;

  /// The data returned by a successful mutation.
  final TData? data;

  /// The error from a failed mutation.
  final Object? error;

  /// Fire-and-forget mutation trigger.
  final void Function(TVariables variables) mutate;

  /// Async mutation trigger that returns the result or throws.
  final Future<TData> Function(TVariables variables) mutateAsync;

  /// Resets the mutation to idle state.
  final VoidCallback reset;

  /// Whether the mutation is in progress.
  bool get isLoading => status == MutationStatus.loading;

  /// Whether the mutation completed successfully.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether the mutation failed.
  bool get isError => status == MutationStatus.error;

  /// Whether the mutation is idle.
  bool get isIdle => status == MutationStatus.idle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MutationResult<TData, TVariables> &&
        other.status == status &&
        other.data == data &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(status, data, error);

  @override
  String toString() {
    return 'MutationResult<$TData, $TVariables>('
        'status: $status, data: $data, error: $error)';
  }
}
