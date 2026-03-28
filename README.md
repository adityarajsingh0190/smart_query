# smart_query

[![pub version](https://img.shields.io/pub/v/smart_query.svg)](https://pub.dev/packages/smart_query)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/AdiSingh-dev/smart_query/blob/main/LICENSE)

**Async server-state management for Flutter** — caching, deduplication, background sync, optimistic updates, and pagination. Inspired by [TanStack Query](https://tanstack.com/query).

Flutter apps spend too much time re-fetching data that hasn't changed, managing loading/error states, and synchronizing server data across screens. 
**smart_query** handles all of this with a single widget — `QueryBuilder` — so you can focus on your UI.

---

## Quick Start

```dart
import 'package:smart_query/smart_query.dart';

// 1. Wrap your app
void main() => runApp(
  QueryClientProvider(
    client: QueryClient(),
    child: MyApp(),
  ),
);

// 2. Fetch data with one widget
QueryBuilder<List<User>>(
  queryKey: ['users'],
  fetcher: () => api.getUsers(),
  builder: (context, result) {
    if (result.isLoading) return CircularProgressIndicator();
    if (result.isError) return Text('Error: ${result.error}');
    return ListView(
      children: result.data!.map((u) => Text(u.name)).toList(),
    );
  },
)
```

That's it. The data is cached, deduplicated, and automatically refetched when stale.

---

## Table of Contents

- [Setup](#setup)
- [QueryBuilder](#querybuilder)
- [Loading / Error / Success States](#loading--error--success-states)
- [Mutations](#mutations)
- [Infinite Scroll](#infinite-scroll)
- [Classic Pagination](#classic-pagination)
- [Background Sync](#background-sync)
- [QueryClient Methods](#queryclient-methods)
- [Advanced Patterns](#advanced-patterns)
- [FAQ](#faq)
- [Migration Guide](#migration-guide)
- [Contributing](#contributing)
- [License](#license)

---

## Setup

### 1. Add the dependency

```yaml
dependencies:
  smart_query: ^1.0.0
```

### 2. Wrap your app with `QueryClientProvider`

```dart
void main() {
  final queryClient = QueryClient(
    defaultOptions: const QueryDefaults(
      staleTime: Duration(minutes: 1),  // Data is fresh for 1 minute
      cacheTime: Duration(minutes: 5),  // Unused cache evicted after 5 minutes
      retry: 3,                         // Retry failed requests 3 times
    ),
  );

  runApp(
    QueryClientProvider(
      client: queryClient,
      child: MyApp(),
    ),
  );
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `staleTime` | `Duration.zero` | How long data is considered fresh. During this window, no refetch occurs. |
| `cacheTime` | `5 minutes` | How long unused data stays in cache after all observers leave. |
| `retry` | `3` | Number of retries on failure. Set to `0` to disable. |
| `retryDelay` | Exponential backoff | Custom function `Duration Function(int attempt)` for retry timing. |
| `refetchOnWindowFocus` | `true` | Refetch stale data when app resumes from background. |
| `refetchOnReconnect` | `true` | Refetch stale data when network connectivity is restored. |
| `refetchInterval` | `null` | If set, polls at this interval while the query has observers. |

---

## QueryBuilder

The primary widget for fetching and displaying server data.

```dart
QueryBuilder<UserProfile>(
  queryKey: ['user', userId],     // Unique cache key
  fetcher: () => api.getUser(userId), // Async function
  staleTime: const Duration(minutes: 5),
  builder: (context, result) {
    if (result.isLoading) return LoadingSkeleton();
    if (result.isError) return ErrorWidget(error: result.error);
    return UserCard(user: result.data!);
  },
)
```

### QueryBuilder Options

| Parameter | Type | Description |
|-----------|------|-------------|
| `queryKey` | `List<dynamic>` | Hierarchical cache key. Changing this triggers a refetch. |
| `fetcher` | `Future<T> Function()` | The async function that returns data. |
| `builder` | `Widget Function(BuildContext, QueryResult<T>)` | Builder called on every state change. |
| `staleTime` | `Duration?` | Override global default. |
| `cacheTime` | `Duration?` | Override global default. |
| `enabled` | `bool` | Set to `false` for dependent queries. Default: `true`. |
| `retry` | `int?` | Override number of retries. |
| `initialData` | `T?` | Show this data immediately (still fetches if stale). |
| `select` | `T Function(T)?` | Transform data before caching. |
| `keepPreviousData` | `bool` | Show old data while a new key loads. Default: `false`. |
| `refetchInterval` | `Duration?` | Poll at this interval. |
| `onSuccess` | `void Function(T, List)?` | Called on successful fetch. |
| `onError` | `void Function(Object, StackTrace, List)?` | Called on error after retries exhausted. |

### QueryResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T?` | The fetched data, or `null`. |
| `error` | `Object?` | The error, or `null`. |
| `status` | `QueryStatus` | Current status: `idle`, `loading`, `success`, `error`, `refreshing`. |
| `isLoading` | `bool` | Initial load, no data yet. |
| `isRefreshing` | `bool` | Has data, fetching updated data in background. |
| `isFetching` | `bool` | Any fetch in progress (`isLoading \|\| isRefreshing`). |
| `isSuccess` | `bool` | Data loaded successfully. |
| `isError` | `bool` | Fetch failed. |
| `isPreviousData` | `bool` | Showing data from a previously-subscribed key. |
| `refetch` | `VoidCallback` | Trigger a manual refetch. |

---

## Loading / Error / Success States

Handle all three states in a single builder:

```dart
QueryBuilder<List<Post>>(
  queryKey: ['posts'],
  fetcher: () => api.getPosts(),
  builder: (context, result) {
    // 1. LOADING — show skeleton or spinner
    if (result.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. ERROR — show error with retry
    if (result.isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: ${result.error}'),
            ElevatedButton(
              onPressed: result.refetch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 3. SUCCESS — show data
    final posts = result.data!;
    return RefreshIndicator(
      onRefresh: () async => result.refetch(),
      child: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (ctx, i) => PostCard(post: posts[i]),
      ),
    );
  },
)
```

**Background refresh**: When data is stale and a refetch occurs, `result.isRefreshing` is `true` while `result.data` still contains the cached data. Show a subtle loading indicator instead of replacing the content.

---

## Mutations

### Basic Mutation

```dart
MutationBuilder<User, UpdateUserParams>(
  mutator: (params) => api.updateUser(params),
  onSuccess: (data, variables, context) {
    // Invalidate related queries to refetch fresh data
    QueryClient.of(context).invalidateQueries(['users']);
  },
  builder: (context, mutation) {
    return ElevatedButton(
      onPressed: mutation.isLoading
          ? null
          : () => mutation.mutate(UpdateUserParams(name: 'Alice')),
      child: mutation.isLoading
          ? const CircularProgressIndicator()
          : const Text('Save'),
    );
  },
)
```

### Optimistic Updates

Update the UI immediately, rollback on error:

```dart
MutationBuilder<User, String>(
  mutator: (newName) => api.updateUserName(newName),

  // Step 1: Optimistic update — save old data, show new data immediately
  onMutate: (newName) {
    final client = QueryClient.of(context);
    final previous = client.getQueryData<User>(['user', userId]);
    client.setQueryData<User>(['user', userId], previous!.copyWith(name: newName));
    return previous; // Return old data as rollback context
  },

  // Step 2: On error — rollback to previous data
  onError: (error, variables, rollbackContext) {
    if (rollbackContext != null) {
      QueryClient.of(context).setQueryData<User>(
        ['user', userId],
        rollbackContext as User,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save: $error')),
    );
  },

  // Step 3: Always refetch to ensure server consistency
  onSettled: (data, error, variables, context2) {
    QueryClient.of(context).invalidateQueries(['user', userId]);
  },

  builder: (context, mutation) {
    return FilledButton(
      onPressed: mutation.isLoading ? null : () => mutation.mutate('New Name'),
      child: Text(mutation.isLoading ? 'Saving...' : 'Save'),
    );
  },
)
```

---

## Infinite Scroll

Use `InfiniteQueryBuilder` for "load more" and endless scrolling:

```dart
InfiniteQueryBuilder<PostsPage, String>(
  queryKey: ['posts', 'feed'],
  fetcher: (cursor) => api.getPosts(cursor: cursor),
  initialPageParam: '',

  // Return the next cursor, or null if no more pages
  getNextPageParam: (lastPage, allPages) => lastPage.nextCursor,

  builder: (context, result) {
    if (result.isLoading) return const CircularProgressIndicator();

    final allPosts = result.pages.expand((page) => page.items).toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Auto-fetch next page near the bottom
        if (notification.metrics.extentAfter < 200 &&
            result.hasNextPage &&
            !result.isFetchingNextPage) {
          result.fetchNextPage();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: allPosts.length + 1,
        itemBuilder: (ctx, index) {
          if (index == allPosts.length) {
            if (result.isFetchingNextPage) {
              return const CircularProgressIndicator();
            }
            if (!result.hasNextPage) {
              return const Text('No more posts');
            }
            return ElevatedButton(
              onPressed: result.fetchNextPage,
              child: const Text('Load More'),
            );
          }
          return PostCard(post: allPosts[index]);
        },
      ),
    );
  },
)
```

### InfiniteQueryResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `pages` | `List<TPage>` | All loaded pages in order. |
| `hasNextPage` | `bool` | Whether more pages are available. |
| `hasPreviousPage` | `bool` | Whether previous pages are available. |
| `isFetchingNextPage` | `bool` | Loading indicator for next page. |
| `fetchNextPage` | `Future<void> Function()` | Trigger next page load. |
| `fetchPreviousPage` | `Future<void> Function()` | Trigger previous page load. |
| `refetch` | `VoidCallback` | Reset all pages and start from page 1. |

---

## Classic Pagination

Use `PaginatedQueryBuilder` for page-number navigation:

```dart
class ProductsScreen extends StatefulWidget { ... }

class _ProductsScreenState extends State<ProductsScreen> {
  int currentPage = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PaginatedQueryBuilder<ProductsResponse>(
            queryKey: ['products'],
            page: currentPage,
            fetcher: (page) => api.getProducts(page: page as int),
            keepPreviousData: true, // Show old page while new one loads
            builder: (context, result) {
              if (result.isLoading && !result.isPreviousData) {
                return const CircularProgressIndicator();
              }

              return AnimatedOpacity(
                opacity: result.isPreviousData ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: ProductGrid(products: result.data!.items),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: currentPage > 1
                  ? () => setState(() => currentPage--)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Page $currentPage'),
            IconButton(
              onPressed: () => setState(() => currentPage++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Background Sync

### App Lifecycle (built-in)

`QueryClientProvider` automatically registers an `AppLifecycleObserver` that refetches all stale queries when your app resumes from the background. This is enabled by default and requires no configuration.

To disable refetch-on-resume for a specific query:

```dart
QueryBuilder<Data>(
  queryKey: ['settings'],
  fetcher: fetchSettings,
  refetchOnWindowFocus: false, // Disable for this query
  builder: (context, result) => ...,
)
```

### Connectivity (bring your own implementation)

smart_query provides an abstract `ConnectivityObserver` interface. Implement it with your preferred package (e.g., `connectivity_plus`):

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smart_query/smart_query.dart';

class ConnectivityPlusObserver implements ConnectivityObserver {
  final _connectivity = Connectivity();

  @override
  Stream<ConnectivityStatus> get onStatusChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.contains(ConnectivityResult.none)
          ? ConnectivityStatus.offline
          : ConnectivityStatus.online;
    });
  }

  @override
  Future<ConnectivityStatus> get currentStatus async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.none)
        ? ConnectivityStatus.offline
        : ConnectivityStatus.online;
  }
}

// Pass to QueryClient
final client = QueryClient(
  connectivityObserver: ConnectivityPlusObserver(),
);
```

---

## QueryClient Methods

Access the client anywhere via `QueryClient.of(context)`:

```dart
final client = QueryClient.of(context);
```

| Method | Description |
|--------|-------------|
| `prefetchQuery(key, fetcher)` | Populate cache before a widget needs it (e.g., in route transitions). |
| `getQueryData<T>(key)` | Read cached data synchronously. Returns `null` if not cached. |
| `setQueryData<T>(key, data)` | Write data directly to cache. Accepts value or `T Function(T? old)` updater. |
| `invalidateQueries(key)` | Mark queries as stale. Active queries refetch immediately. Supports prefix matching. |
| `cancelQueries(key)` | Cancel in-flight fetches. Used before `setQueryData` in optimistic updates. |
| `removeQueries(key)` | Remove queries from cache entirely. |
| `clear()` | Clear all cached data. Use on logout. |

### Hierarchical Invalidation

Keys are hierarchical. Invalidating a prefix invalidates all matching queries:

```dart
// These queries exist in cache:
// ['user', 1]
// ['user', 2]  
// ['user', 1, 'posts']

// Invalidate ALL user queries at once:
client.invalidateQueries(['user']); // Matches all three

// Invalidate only user 1's queries:
client.invalidateQueries(['user', 1]); // Matches ['user', 1] and ['user', 1, 'posts']
```

---

## Advanced Patterns

### Dependent Queries

Use `enabled` to chain queries — the second one waits for the first:

```dart
QueryBuilder<User>(
  queryKey: ['user', userId],
  fetcher: () => api.getUser(userId),
  builder: (context, userResult) {
    return QueryBuilder<List<Post>>(
      queryKey: ['posts', userResult.data?.id],
      fetcher: () => api.getUserPosts(userResult.data!.id),
      enabled: userResult.data != null, // Only fetch when user data is available
      builder: (context, postsResult) {
        // ...
      },
    );
  },
)
```

### Query Key Structure

Keys should be hierarchical and include all variables the query depends on:

```dart
// ✅ Good — specific, hierarchical
['user', userId]
['user', userId, 'posts']
['products', {'filter': 'active', 'page': 1}]

// ❌ Bad — not specific enough
['data']
['fetch']
```

**Map key order doesn't matter** — `{'b': 2, 'a': 1}` and `{'a': 1, 'b': 2}` produce the same cache key.

### Prefetching

Populate the cache before navigating to a new screen:

```dart
onTap: () async {
  await QueryClient.of(context).prefetchQuery(
    ['user', userId],
    () => api.getUser(userId),
  );
  Navigator.push(context, UserScreen(userId: userId));
},
```

---

## Devtools

Built-in devtools are planned for a future release. The `QueryCache` emits a `Stream<CacheEvent>` that you can use for logging today:

```dart
queryClient.cache.events.listen((event) {
  debugPrint('Cache ${event.type}: ${event.key}');
});
```

---

## FAQ

### How is this different from Riverpod?

Riverpod is a general-purpose state management solution. smart_query focuses specifically on **server state** — data that lives on a server and needs to be fetched, cached, synchronized, and invalidated. Riverpod manages application/UI state (theme, form values, routing). They solve different problems.

### How is this different from Bloc?

Bloc is an architecture pattern for managing UI state with events and states. smart_query manages **server state** — the data from your API. You still need Bloc (or Riverpod, or Provider) for UI state like form inputs, navigation, and local preferences. smart_query replaces the boilerplate of "loading, error, success" states for network requests.

### Does this work with Riverpod/Bloc?

**Yes.** They manage UI state; smart_query manages server state. Use them together:
- **Bloc** handles form validation, navigation, user preferences
- **smart_query** handles API data, caching, background sync, pagination

### Does this work with GraphQL?

Yes. The `fetcher` function is a simple `Future<T> Function()`. Use any GraphQL client inside it:

```dart
QueryBuilder<UserData>(
  queryKey: ['user', userId],
  fetcher: () async {
    final result = await graphqlClient.query(GetUserQuery(id: userId));
    return result.data!;
  },
  builder: (context, result) => ...,
)
```

### How do I persist the cache across app restarts?

v1.0 does not include built-in cache persistence. The cache is in-memory only. For persistent caching, you can:
1. Use `initialData` to seed from local storage
2. Set up a persistence layer that listens to cache events
3. Wait for a future release with built-in persistence support

### Known Limitations

- **No persistent cache** — Cache is in-memory only, cleared on app restart.
- **No offline mutation queue** — Mutations that fail while offline are not queued for retry on reconnect.
- **No structural sharing** — Full data replacement on refetch (no diff-based updates).

---

## Migration Guide

This is v1.0.0. No migration guide is needed yet. Future breaking changes will be documented here.

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Write tests for your changes
4. Ensure `flutter test` and `flutter analyze` pass
5. Submit a pull request

---

## License

MIT License. See [LICENSE](LICENSE) for details.
