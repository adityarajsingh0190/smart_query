import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../models/query_options.dart';
import '../models/query_status.dart';
import '../widgets/infinite_query_builder.dart';

/// A hook that manages infinite scroll / "Load more" patterns.
InfiniteQueryResult<TPage> useInfiniteQuery<TPage, TPageParam>({
  required List<dynamic> queryKey,
  required PagedQueryFetcher<TPage, TPageParam> fetcher,
  required TPageParam initialPageParam,
  required TPageParam? Function(TPage lastPage, List<TPage> allPages)
      getNextPageParam,
  TPageParam? Function(TPage firstPage, List<TPage> allPages)?
      getPreviousPageParam,
  Duration? staleTime,
  Duration? cacheTime,
  bool enabled = true,
  int? retry,
  RetryDelayFn? retryDelay,
  RetryWhenFn? retryWhen,
}) {
  final pages = useRef<List<TPage>>([]);
  final pageParams = useRef<List<dynamic>>([]);

  final status = useState<QueryStatus>(QueryStatus.idle);
  final error = useState<Object?>(null);
  final errorStackTrace = useState<StackTrace?>(null);

  final isFetchingNextPage = useState<bool>(false);
  final isFetchingPreviousPage = useState<bool>(false);
  final hasNextPage = useState<bool>(true);
  final hasPreviousPage = useState<bool>(false);
  final dataUpdatedAt = useState<DateTime?>(null);

  final isDisposed = useRef<bool>(false);

  void updatePageFlags() {
    if (pages.value.isNotEmpty) {
      final nextParam = getNextPageParam(pages.value.last, pages.value);
      hasNextPage.value = nextParam != null;

      if (getPreviousPageParam != null) {
        final prevParam = getPreviousPageParam(pages.value.first, pages.value);
        hasPreviousPage.value = prevParam != null;
      }
    }
  }

  Future<void> fetchFirstPage() async {
    if (isDisposed.value) return;
    status.value = QueryStatus.loading;
    error.value = null;

    try {
      final page = await fetcher(initialPageParam);
      if (isDisposed.value) return;
      pages.value = [page];
      pageParams.value = [initialPageParam];
      status.value = QueryStatus.success;
      dataUpdatedAt.value = DateTime.now();
      updatePageFlags();
    } catch (e, st) {
      if (isDisposed.value) return;
      error.value = e;
      errorStackTrace.value = st;
      status.value = QueryStatus.error;
    }
  }

  Future<void> fetchNextPage() async {
    if (isDisposed.value || !hasNextPage.value || isFetchingNextPage.value) {
      return;
    }
    if (pages.value.isEmpty) return;

    final nextParam = getNextPageParam(pages.value.last, pages.value);
    if (nextParam == null) {
      hasNextPage.value = false;
      return;
    }

    isFetchingNextPage.value = true;

    try {
      final page = await fetcher(nextParam);
      if (isDisposed.value) return;
      pages.value = [...pages.value, page];
      pageParams.value = [...pageParams.value, nextParam];
      isFetchingNextPage.value = false;
      dataUpdatedAt.value = DateTime.now();
      updatePageFlags();
    } catch (e, st) {
      if (isDisposed.value) return;
      error.value = e;
      errorStackTrace.value = st;
      isFetchingNextPage.value = false;
    }
  }

  Future<void> fetchPreviousPage() async {
    if (isDisposed.value ||
        !hasPreviousPage.value ||
        isFetchingPreviousPage.value ||
        getPreviousPageParam == null) {
      return;
    }
    if (pages.value.isEmpty) return;

    final prevParam = getPreviousPageParam(pages.value.first, pages.value);
    if (prevParam == null) {
      hasPreviousPage.value = false;
      return;
    }

    isFetchingPreviousPage.value = true;

    try {
      final page = await fetcher(prevParam);
      if (isDisposed.value) return;
      pages.value = [page, ...pages.value];
      pageParams.value = [prevParam, ...pageParams.value];
      isFetchingPreviousPage.value = false;
      dataUpdatedAt.value = DateTime.now();
      updatePageFlags();
    } catch (e, st) {
      if (isDisposed.value) return;
      error.value = e;
      errorStackTrace.value = st;
      isFetchingPreviousPage.value = false;
    }
  }

  void refetch() {
    pages.value = [];
    pageParams.value = [];
    hasNextPage.value = true;
    hasPreviousPage.value = false;
    error.value = null;
    errorStackTrace.value = null;
    fetchFirstPage();
  }

  useEffect(() {
    isDisposed.value = false;
    if (enabled) {
      fetchFirstPage();
    }
    return () {
      isDisposed.value = true;
    };
  }, [enabled, queryKey]);

  return InfiniteQueryResult<TPage>(
    pages: List.unmodifiable(pages.value),
    status: status.value,
    error: error.value,
    errorStackTrace: errorStackTrace.value,
    hasNextPage: hasNextPage.value,
    hasPreviousPage: hasPreviousPage.value,
    isFetchingNextPage: isFetchingNextPage.value,
    isFetchingPreviousPage: isFetchingPreviousPage.value,
    fetchNextPage: fetchNextPage,
    fetchPreviousPage: fetchPreviousPage,
    refetch: refetch,
    dataUpdatedAt: dataUpdatedAt.value,
  );
}
