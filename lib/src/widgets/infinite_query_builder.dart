import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/query_options.dart';
import '../models/query_status.dart';

/// Result exposed to the builder of [InfiniteQueryBuilder].
class InfiniteQueryResult<TPage> {
  /// Creates an infinite query result.
  const InfiniteQueryResult({
    required this.pages,
    required this.status,
    this.error,
    this.errorStackTrace,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.refetch,
    this.dataUpdatedAt,
  });

  /// All loaded pages in order.
  final List<TPage> pages;

  /// The current status.
  final QueryStatus status;

  /// The last error, if any.
  final Object? error;

  /// Stack trace of the last error.
  final StackTrace? errorStackTrace;

  /// Whether more pages are available after the last loaded page.
  final bool hasNextPage;

  /// Whether more pages are available before the first loaded page.
  final bool hasPreviousPage;

  /// Whether the next page is currently being fetched.
  final bool isFetchingNextPage;

  /// Whether the previous page is currently being fetched.
  final bool isFetchingPreviousPage;

  /// Fetches the next page. No-op if [hasNextPage] is `false` or
  /// [isFetchingNextPage] is `true`.
  final Future<void> Function() fetchNextPage;

  /// Fetches the previous page. No-op if [hasPreviousPage] is `false` or
  /// [isFetchingPreviousPage] is `true`.
  final Future<void> Function() fetchPreviousPage;

  /// Resets all pages and re-fetches from the first page.
  final VoidCallback refetch;

  /// Whether any page has been loaded.
  bool get isLoading => status == QueryStatus.loading && pages.isEmpty;

  /// Whether an error occurred.
  bool get isError => status == QueryStatus.error;

  /// Whether at least one page was loaded successfully.
  bool get isSuccess => status == QueryStatus.success;

  /// When data was last successfully fetched.
  final DateTime? dataUpdatedAt;
}

/// A widget that manages infinite scroll / "Load more" patterns.
///
/// ```dart
/// InfiniteQueryBuilder<PostListPage, String>(
///   queryKey: ['posts'],
///   fetcher: (pageParam) => api.getPosts(cursor: pageParam),
///   initialPageParam: '',
///   getNextPageParam: (lastPage, allPages) => lastPage.nextCursor,
///   builder: (context, result) {
///     if (result.isLoading) return CircularProgressIndicator();
///     return ListView.builder(
///       itemCount: result.pages.length + (result.hasNextPage ? 1 : 0),
///       itemBuilder: (ctx, index) { ... },
///     );
///   },
/// )
/// ```
class InfiniteQueryBuilder<TPage, TPageParam> extends StatefulWidget {
  /// Creates an [InfiniteQueryBuilder].
  const InfiniteQueryBuilder({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.initialPageParam,
    required this.getNextPageParam,
    this.getPreviousPageParam,
    required this.builder,
    this.staleTime,
    this.cacheTime,
    this.enabled = true,
    this.retry,
    this.retryDelay,
    this.retryWhen,
  });

  /// The query key for cache lookup.
  final List<dynamic> queryKey;

  /// Fetches a page given the page parameter.
  final PagedQueryFetcher<TPage, TPageParam> fetcher;

  /// The initial page parameter (e.g., first page number or empty cursor).
  final TPageParam initialPageParam;

  /// Extracts the next page parameter from the last loaded page.
  /// Return `null` to signal no more pages.
  final TPageParam? Function(TPage lastPage, List<TPage> allPages)
      getNextPageParam;

  /// Extracts the previous page parameter from the first loaded page.
  /// Return `null` to signal no previous pages.
  final TPageParam? Function(TPage firstPage, List<TPage> allPages)?
      getPreviousPageParam;

  /// Builder function called with the infinite query result.
  final Widget Function(BuildContext context, InfiniteQueryResult<TPage> result)
      builder;

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
  State<InfiniteQueryBuilder<TPage, TPageParam>> createState() =>
      _InfiniteQueryBuilderState<TPage, TPageParam>();
}

class _InfiniteQueryBuilderState<TPage, TPageParam>
    extends State<InfiniteQueryBuilder<TPage, TPageParam>> {
  final List<TPage> _pages = [];
  final List<dynamic> _pageParams = [];

  QueryStatus _status = QueryStatus.idle;
  Object? _error;
  StackTrace? _errorStackTrace;

  bool _isFetchingNextPage = false;
  bool _isFetchingPreviousPage = false;
  bool _hasNextPage = true;
  bool _hasPreviousPage = false;
  bool _disposed = false;
  DateTime? _dataUpdatedAt;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _fetchFirstPage();
    }
  }

  @override
  void didUpdateWidget(InfiniteQueryBuilder<TPage, TPageParam> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _fetchFirstPage();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _fetchFirstPage() async {
    if (_disposed) return;
    setState(() {
      _status = QueryStatus.loading;
      _error = null;
    });

    try {
      final page = await widget.fetcher(widget.initialPageParam);
      if (_disposed) return;
      setState(() {
        _pages
          ..clear()
          ..add(page);
        _pageParams
          ..clear()
          ..add(widget.initialPageParam);
        _status = QueryStatus.success;
        _dataUpdatedAt = DateTime.now();
        _updatePageFlags();
      });
    } catch (e, st) {
      if (_disposed) return;
      setState(() {
        _error = e;
        _errorStackTrace = st;
        _status = QueryStatus.error;
      });
    }
  }

  Future<void> _fetchNextPage() async {
    if (_disposed || !_hasNextPage || _isFetchingNextPage) return;
    if (_pages.isEmpty) return;

    final nextParam = widget.getNextPageParam(_pages.last, _pages);
    if (nextParam == null) {
      setState(() => _hasNextPage = false);
      return;
    }

    setState(() => _isFetchingNextPage = true);

    try {
      final page = await widget.fetcher(nextParam);
      if (_disposed) return;
      setState(() {
        _pages.add(page);
        _pageParams.add(nextParam);
        _isFetchingNextPage = false;
        _dataUpdatedAt = DateTime.now();
        _updatePageFlags();
      });
    } catch (e, st) {
      if (_disposed) return;
      setState(() {
        _error = e;
        _errorStackTrace = st;
        _isFetchingNextPage = false;
      });
    }
  }

  Future<void> _fetchPreviousPage() async {
    if (_disposed ||
        !_hasPreviousPage ||
        _isFetchingPreviousPage ||
        widget.getPreviousPageParam == null) {
      return;
    }
    if (_pages.isEmpty) return;

    final prevParam = widget.getPreviousPageParam!(_pages.first, _pages);
    if (prevParam == null) {
      setState(() => _hasPreviousPage = false);
      return;
    }

    setState(() => _isFetchingPreviousPage = true);

    try {
      final page = await widget.fetcher(prevParam);
      if (_disposed) return;
      setState(() {
        _pages.insert(0, page);
        _pageParams.insert(0, prevParam);
        _isFetchingPreviousPage = false;
        _dataUpdatedAt = DateTime.now();
        _updatePageFlags();
      });
    } catch (e, st) {
      if (_disposed) return;
      setState(() {
        _error = e;
        _errorStackTrace = st;
        _isFetchingPreviousPage = false;
      });
    }
  }

  void _refetch() {
    _pages.clear();
    _pageParams.clear();
    _hasNextPage = true;
    _hasPreviousPage = false;
    _error = null;
    _errorStackTrace = null;
    _fetchFirstPage();
  }

  void _updatePageFlags() {
    if (_pages.isNotEmpty) {
      final nextParam = widget.getNextPageParam(_pages.last, _pages);
      _hasNextPage = nextParam != null;

      if (widget.getPreviousPageParam != null) {
        final prevParam = widget.getPreviousPageParam!(_pages.first, _pages);
        _hasPreviousPage = prevParam != null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      InfiniteQueryResult<TPage>(
        pages: List.unmodifiable(_pages),
        status: _status,
        error: _error,
        errorStackTrace: _errorStackTrace,
        hasNextPage: _hasNextPage,
        hasPreviousPage: _hasPreviousPage,
        isFetchingNextPage: _isFetchingNextPage,
        isFetchingPreviousPage: _isFetchingPreviousPage,
        fetchNextPage: _fetchNextPage,
        fetchPreviousPage: _fetchPreviousPage,
        refetch: _refetch,
        dataUpdatedAt: _dataUpdatedAt,
      ),
    );
  }
}
