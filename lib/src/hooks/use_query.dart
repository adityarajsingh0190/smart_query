import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/query_client.dart';
import '../models/query_options.dart';
import '../models/query_result.dart';

/// A hook that subscribes to a query and returns its current state.
QueryResult<T> useQuery<T>({
  required List<dynamic> queryKey,
  required QueryFetcher<T> fetcher,
  Duration? staleTime,
  Duration? cacheTime,
  bool enabled = true,
  int? retry,
  RetryDelayFn? retryDelay,
  RetryWhenFn? retryWhen,
  bool? refetchOnWindowFocus,
  bool? refetchOnReconnect,
  Duration? refetchInterval,
  void Function(T data, List<dynamic> key)? onSuccess,
  void Function(Object error, StackTrace st, List<dynamic> key)? onError,
  void Function(T? data, Object? error)? onSettled,
  T? initialData,
  T Function(T data)? select,
  bool keepPreviousData = false,
}) {
  final context = useContext();
  final client = QueryClient.of(context);
  final defaults = client.defaultOptions;

  final options = useMemoized(
    () => QueryOptions<T>(
      key: queryKey,
      fetcher: fetcher,
      staleTime: staleTime ?? defaults.staleTime,
      cacheTime: cacheTime ?? defaults.cacheTime,
      enabled: enabled,
      retry: retry ?? defaults.retry,
      retryDelay: retryDelay ?? defaults.retryDelay,
      retryWhen: retryWhen ?? defaults.retryWhen,
      refetchOnWindowFocus:
          refetchOnWindowFocus ?? defaults.refetchOnWindowFocus,
      refetchOnReconnect: refetchOnReconnect ?? defaults.refetchOnReconnect,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      initialData: initialData,
      select: select,
      keepPreviousData: keepPreviousData,
    ),
    [
      queryKey,
      staleTime,
      cacheTime,
      enabled,
      retry,
      refetchOnWindowFocus,
      refetchOnReconnect,
      refetchInterval,
      initialData,
      keepPreviousData,
    ],
  );

  return _useQueryObserver<T>(client, queryKey, options);
}

QueryResult<T> _useQueryObserver<T>(
    QueryClient client, List<dynamic> queryKey, QueryOptions<T> options) {
  final query = useMemoized(
      () => client.cache.getOrCreate<T>(queryKey, options),
      [queryKey, options]);
  final previousResult = useRef<QueryResult<T>?>(null);

  final state = useState<QueryResult<T>?>(null);

  useEffect(() {
    query.addObserver();

    var currentResult = query.currentResult;
    if (options.keepPreviousData &&
        currentResult.data == null &&
        previousResult.value?.data != null) {
      currentResult = currentResult.copyWith(
        data: previousResult.value!.data,
        isPreviousData: true,
      );
    }
    state.value = currentResult;

    if (options.enabled) {
      query.fetch();
    }

    final subscription = query.stream.listen((newResult) {
      if (options.keepPreviousData &&
          newResult.data == null &&
          previousResult.value?.data != null) {
        state.value = newResult.copyWith(
          data: previousResult.value!.data,
          isPreviousData: true,
        );
      } else {
        state.value = newResult;
        if (newResult.data != null) {
          previousResult.value = null;
        }
      }
    });

    return () {
      if (options.keepPreviousData && state.value?.data != null) {
        previousResult.value = state.value;
      }
      subscription.cancel();
      query.removeObserver();
    };
  }, [query, options.enabled, options.keepPreviousData]);

  return state.value ??
      QueryResult<T>.idle(
        refetch: () => query.fetch(force: true),
      );
}
