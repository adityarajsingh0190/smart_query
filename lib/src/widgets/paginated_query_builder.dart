import 'package:flutter/widgets.dart';

import '../models/query_options.dart';
import '../models/query_result.dart';
import 'query_builder.dart';

/// A convenience widget for classic page-based pagination.
///
/// Internally wraps [QueryBuilder] with the page number included in the key.
/// Supports [keepPreviousData] to show old page data while the new page loads.
///
/// ```dart
/// PaginatedQueryBuilder<UserListResponse>(
///   queryKey: ['users'],
///   page: currentPage,
///   fetcher: (page) => api.getUsers(page: page),
///   keepPreviousData: true,
///   builder: (context, result) {
///     if (result.isLoading && !result.isPreviousData) {
///       return CircularProgressIndicator();
///     }
///     return Opacity(
///       opacity: result.isPreviousData ? 0.5 : 1.0,
///       child: UserList(users: result.data!.users),
///     );
///   },
/// )
/// ```
class PaginatedQueryBuilder<T> extends StatelessWidget {
  /// Creates a [PaginatedQueryBuilder].
  const PaginatedQueryBuilder({
    super.key,
    required this.queryKey,
    required this.page,
    required this.fetcher,
    required this.builder,
    this.keepPreviousData = true,
    this.staleTime,
    this.cacheTime,
    this.enabled = true,
    this.retry,
    this.retryDelay,
    this.retryWhen,
  });

  /// The base query key (the page number is appended automatically).
  final List<dynamic> queryKey;

  /// The current page number or parameter.
  final dynamic page;

  /// Fetches data for the given page.
  final Future<T> Function(dynamic page) fetcher;

  /// Builder function called with the query result.
  final Widget Function(BuildContext context, QueryResult<T> result) builder;

  /// Whether to keep showing previous page data while new page loads.
  final bool keepPreviousData;

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

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<T>(
      queryKey: [...queryKey, page],
      fetcher: () => fetcher(page),
      builder: builder,
      keepPreviousData: keepPreviousData,
      staleTime: staleTime,
      cacheTime: cacheTime,
      enabled: enabled,
      retry: retry,
      retryDelay: retryDelay,
      retryWhen: retryWhen,
    );
  }
}
