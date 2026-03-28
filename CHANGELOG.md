# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-28

### Added

- **QueryBuilder** — Declarative widget for fetching, caching, and displaying server data with automatic refetching.
- **MutationBuilder** — Widget for performing create/update/delete operations with optimistic update support.
- **InfiniteQueryBuilder** — Widget for cursor-based infinite scroll and "Load more" patterns.
- **PaginatedQueryBuilder** — Widget for classic page-number pagination with `keepPreviousData`.
- **QueryClient** — Central API for cache operations: `prefetchQuery`, `invalidateQueries`, `setQueryData`, `cancelQueries`, `getQueryData`.
- **QueryCache** — In-memory cache with deterministic key serialization, hierarchical prefix invalidation, and observer-based eviction.
- **Query state machine** — Full lifecycle with `idle`, `loading`, `success`, `error`, `refreshing` states.
- **Automatic retry** — Configurable retry count with exponential backoff and jitter.
- **Fetch deduplication** — Multiple subscribers share a single in-flight network request.
- **Stale-while-revalidate** — Show cached data immediately, refetch in background.
- **Background sync** — `AppLifecycleObserver` refetches stale data on app resume with 500ms debounce.
- **Connectivity awareness** — Abstract `ConnectivityObserver` interface for refetch on reconnect.
- **Query defaults** — Global default options (`staleTime`, `cacheTime`, `retry`, etc.) via `QueryDefaults`.
- Example app demonstrating all features with JSONPlaceholder API.
