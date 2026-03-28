# Smart Query Example App

This example app demonstrates how to integrate `smart_query` into a real-world Flutter application.
It showcases fetching data, caching, mutations, pagination, and infinite scrolling using
the [DummyJSON](https://dummyjson.com/) API and the `dio` network client.

## What are we optimizing? (Before vs. After)

Normally, in a standard Flutter app, developers rely on `FutureBuilder` or manually call
`setState(isLoading = true/false)` every time a screen requires data from the network.

### Before `smart_query`

- **Redundant Network Requests:** Every time a user navigates between the "Home" and "Profile"
  pages, the app blindly refetches the exact same data from the remote server, needlessly eating up
  mobile data and introducing latency delays.
- **Loading Spinners Everywhere:** Users constantly hit a full-screen loading spinner while waiting
  for network calls to finish when they click on a tab or change a page.
- **Complex Pagination State:** Infinite scrolling means managing `ScrollController` offsets,
  catching network errors mid-scroll, tracking an `isLoadingMore` boolean flag, and carefully
  appending new lists to an existing array. It requires dozens of lines of delicate boilerplate
  code.
- **Painful Mutations:** Updating server data (like changing a username) means sending the POST
  protocol, waiting multiple seconds for the response, blocking the UI with a spinner, and then
  manually re-querying the data list to show the new name.

### After `smart_query`

- **Instant Loads and Global Caching:** Data is globally cached based on unique `queryKeys` like
  `['posts']`. Navigating back to the "Home" tab instantly restores the cached posts with 0ms delay
  while silently checking for background updates.
- **Background Synchronization:** The app monitors active network connections and app lifecycle
  states. If you lock your phone or lose cell service and return an hour later, the app
  automatically refreshes stale queries in the background and slides in fresh data.
- **`keepPreviousData` Magic:** When navigating between pages in a multi-page list view, the old
  data stays perfectly visible on screen instead of jumping to a loading screen. Only a subtle
  progress indicator signals that the next page is loading.
- **Optimistic Updates:** When a user changes their profile name, the app's UI updates in the exact
  same millisecond. If the simulated API call later reports a failure, the package automatically
  rolls back the cache and UI to the exact previous state in the blink of an eye.

---

## App Features & Package Usage

This example is split into 4 main demonstration pages, each highlighting core mechanics of the
package:

### 1. Basic Fetching & Caching (`home_page.dart`)

- **Package Feature:** `QueryBuilder`
- **How we do it:** The home page calls the `/posts` endpoint utilizing a `QueryBuilder` with key
  `['posts', 'home']`.
- **Optimization:** We explicitly define a `staleTime` of 2 minutes. The list of posts loads once.
  For the next 2 minutes, any widget destroying and rebuilding on that screen skips the network
  cycle entirely and pulls immediately from the `QueryClientCache`. We also add a silent
  `.isRefreshing` indicator for `RefreshIndicator` pulls.

### 2. Mutations & Optimistic Updates (`profile_page.dart`)

- **Package Feature:** `MutationBuilder` & `QueryClient.setQueryData()`
- **How we do it:** A user alters their username via a `TextField` form. When they tap Save, a
  `MutationBuilder` triggers an asynchronous `mutator`.
- **Optimization:** An `onMutate` hook runs *before* the network call starts. We extract the old
  name from the cache, temporarily force the new name into the cache using `client.setQueryData`,
  and instantly re-render the screen. A simulated 30% chance of server failure demonstrates an
  `onError` rollback where the exact previous user object is seamlessly injected back into the UI.

### 3. Infinite Scrolling (`posts_page.dart`)

- **Package Feature:** `InfiniteQueryBuilder`
- **How we do it:** Wrapping the dummy API with a deterministic `getNextPageParam` logic constraint.
- **Optimization:** The builder receives a flattened list of all accumulated `pages`. A generic
  `ScrollNotification` listener detects when the user scrolls near the bottom of the list and
  automatically executes `result.fetchNextPage()`. The package manages the complex state machine
  dictating `result.isFetchingNextPage` vs `result.isLoading`. Loading spinners are isolated
  entirely to the footer.

### 4. Seamless Pagination (`products_page.dart`)

- **Package Feature:** `PaginatedQueryBuilder`
- **How we do it:** The builder wraps a standard `QueryBuilder`, automatically appending the `page`
  integer directly to the query key.
- **Optimization:** We explicitly set `keepPreviousData: true`. When a user clicks "Page 2", the
  package holds on to the cached result of "Page 1". We apply an `AnimatedOpacity` to visibly dim
  the old array in the UI until the Promise for "Page 2" resolves, dramatically smoothing the user
  experience.

### 5. Global Background Refetching (`main.dart`)

- **Package Feature:** `QueryClientProvider` & `AppLifecycleObserver`
- **How we do it:** Wrap `MaterialApp` with `QueryClientProvider`.
- **Optimization:** The provider registers a built-in `WidgetsBindingObserver`. It listens for
  `AppLifecycleState.resumed`. If a user leaves the app running in the background while checking a
  text message and returns, any query currently rendered on the screen that has exceeded its
  `staleTime` will automatically refetch itself in the background without developer intervention.
