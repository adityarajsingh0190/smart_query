import '../core/query.dart';
import '../core/query_client.dart';
import '../models/query_options.dart';
import '../models/query_result.dart';

/// A utility interface for building observer patterns with custom state maps.
/// Primarily used as the base subscription wrapper for `useQuery`.
class QueryObserver<T> {
  final QueryClient client;
  final QueryOptions<T> options;
  final List<dynamic> queryKey;

  Query<T>? _query;

  QueryObserver({
    required this.client,
    required this.queryKey,
    required this.options,
  });

  QueryResult<T> subscribe(void Function(QueryResult<T>) listener) {
    _query = client.cache.getOrCreate<T>(queryKey, options);
    _query!.addObserver();

    if (options.enabled) {
      _query!.fetch();
    }

    _query!.stream.listen(listener);
    return _query!.currentResult;
  }

  void unsubscribe() {
    _query?.removeObserver();
    _query = null;
  }
}
