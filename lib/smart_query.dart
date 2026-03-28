/// Async server-state management for Flutter — caching, deduplication,
/// background sync, optimistic updates, and pagination.
///
/// Inspired by TanStack Query (React Query), built idiomatically for Flutter.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Wrap your app
/// void main() {
///   runApp(
///     QueryClientProvider(
///       client: QueryClient(),
///       child: MyApp(),
///     ),
///   );
/// }
///
/// // 2. Use QueryBuilder
/// QueryBuilder<List<User>>(
///   queryKey: ['users'],
///   fetcher: () => api.getUsers(),
///   builder: (context, result) {
///     if (result.isLoading) return CircularProgressIndicator();
///     if (result.isError) return Text('Error: ${result.error}');
///     return ListView(
///       children: result.data!.map((u) => Text(u.name)).toList(),
///     );
///   },
/// )
/// ```
library smart_query;

// Models
export 'src/models/query_status.dart';
export 'src/models/query_options.dart'
    show
        QueryOptions,
        MutationOptions,
        QueryFetcher,
        PagedQueryFetcher,
        MutatorFn,
        RetryDelayFn,
        RetryWhenFn,
        OnMutateFn,
        OnMutationSuccessFn,
        OnMutationErrorFn,
        OnMutationSettledFn;
export 'src/models/query_result.dart';
export 'src/models/query_defaults.dart';
export 'src/models/infinite_query_data.dart';

// Core
export 'src/core/query_client.dart';

// Widgets
export 'src/widgets/query_client_provider.dart';
export 'src/widgets/query_builder.dart';
export 'src/widgets/mutation_builder.dart';
export 'src/widgets/infinite_query_builder.dart'
    show InfiniteQueryBuilder, InfiniteQueryResult;
export 'src/widgets/paginated_query_builder.dart';

// Observers
export 'src/observers/connectivity_observer.dart';
