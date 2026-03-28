import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/smart_query.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient(
      defaultOptions: const QueryDefaults(
        retry: 0,
      ),
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('InfiniteQueryBuilder', () {
    testWidgets('fetchNextPage appends data from next page', (tester) async {
      int nextCallCount = 0;
      InfiniteQueryResult<List<String>>? lastResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteQueryBuilder<List<String>, int>(
              queryKey: const ['infinite_test'],
              initialPageParam: 0,
              fetcher: (page) async {
                nextCallCount++;
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return ['Item $page'];
              },
              getNextPageParam: (lastPage, allPages) => allPages.length,
              builder: (context, result) {
                lastResult = result;
                if (result.isLoading) return const Text('Loading');
                return Text('Pages: ${result.pages.length}');
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(lastResult?.pages.length, 1);
      expect(lastResult?.pages.first, ['Item 0']);
      expect(nextCallCount, 1);

      // Trigger fetchNextPage
      lastResult!.fetchNextPage();
      await tester.pump(); // Start fetch
      expect(lastResult?.isFetchingNextPage, true);

      await tester.pump(const Duration(milliseconds: 50)); // Complete fetch
      expect(lastResult?.pages.length, 2);
      expect(lastResult?.pages[0], ['Item 0']);
      expect(lastResult?.pages[1], ['Item 1']);
      expect(nextCallCount, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      client.clear();
    });

    testWidgets('getNextPageParam returning null sets hasNextPage to false',
        (tester) async {
      InfiniteQueryResult<List<String>>? lastResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteQueryBuilder<List<String>, int>(
              queryKey: const ['infinite_test_null'],
              initialPageParam: 0,
              fetcher: (page) async => ['Item $page'],
              getNextPageParam: (lastPage, allPages) =>
                  null, // null means no more pages
              builder: (context, result) {
                lastResult = result;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(lastResult?.hasNextPage, false);

      // Additional test: fetchNextPage is a no-op when hasNextPage is false
      lastResult!.fetchNextPage();
      await tester.pumpAndSettle();
      // Length should still be 1
      expect(lastResult?.pages.length, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      client.clear();
    });

    testWidgets('fetchNextPage is no-op when isFetchingNextPage is true',
        (tester) async {
      int fetchCount = 0;
      InfiniteQueryResult<List<String>>? lastResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteQueryBuilder<List<String>, int>(
              queryKey: const ['infinite_test_dup'],
              initialPageParam: 0,
              fetcher: (page) async {
                fetchCount++;
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return ['Item $page'];
              },
              getNextPageParam: (lastPage, allPages) => allPages.length,
              builder: (context, result) {
                lastResult = result;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Wait for first page to load
      await tester.pump(const Duration(milliseconds: 50));
      expect(fetchCount, 1);

      // Call fetchNextPage concurrently multiple times
      lastResult!.fetchNextPage();
      // Second call should be a no-op because isFetchingNextPage is already true from the first call.
      // We must pump a frame to let the setState from the first call take effect before calling again.
      // Actually, fetchNextPage setState happens immediately.
      await tester.pump();
      lastResult!.fetchNextPage();

      await tester.pump(const Duration(milliseconds: 50));

      // Ensure fetcher is only called once for the next page, totaling 2
      expect(fetchCount, 2);
      expect(lastResult?.pages.length, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      client.clear();
    });

    testWidgets('refetch resets all pages and re-fetches from first',
        (tester) async {
      int fetchCount = 0;
      InfiniteQueryResult<List<String>>? lastResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteQueryBuilder<List<String>, int>(
              queryKey: const ['infinite_test_refetch'],
              initialPageParam: 0,
              fetcher: (page) async {
                fetchCount++;
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return ['Item $page'];
              },
              getNextPageParam: (lastPage, allPages) => allPages.length,
              builder: (context, result) {
                lastResult = result;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      lastResult!.fetchNextPage();
      await tester.pumpAndSettle();
      expect(lastResult?.pages.length, 2);
      expect(fetchCount, 2);

      // Refetch
      lastResult!.refetch();
      await tester.pump();
      expect(lastResult?.pages.isEmpty, true);
      expect(lastResult?.status, QueryStatus.loading);

      await tester.pumpAndSettle();
      expect(lastResult?.pages.length, 1);
      expect(fetchCount, 3);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      client.clear();
    });
  });

  group('PaginatedQueryBuilder (keepPreviousData)', () {
    testWidgets('keepPreviousData shows old data while new page loads',
        (tester) async {
      int page = 1;
      QueryResult<String>? lastResult;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return QueryClientProvider(
              client: client,
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      PaginatedQueryBuilder<String>(
                        queryKey: const ['paginated_test'],
                        page: page,
                        fetcher: (p) async {
                          await Future<void>.delayed(
                              const Duration(milliseconds: 50));
                          return 'Data for page $p';
                        },
                        keepPreviousData: true,
                        builder: (context, result) {
                          lastResult = result;
                          return Text(result.data ?? 'No Data');
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => page = 2),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      // Loading page 1
      await tester.pump();
      expect(lastResult?.status, QueryStatus.loading);
      await tester.pump(const Duration(milliseconds: 50));
      expect(lastResult?.data, 'Data for page 1');
      expect(lastResult?.isPreviousData, false);

      // Navigate to page 2
      await tester.tap(find.text('Next'));
      await tester.pump(); // Starts loading page 2
      await tester
          .pump(); // Flush the microtask to get the updated loading state

      // While loading page 2, we should still see page 1's data!
      expect(lastResult?.data, 'Data for page 1');
      expect(lastResult?.isPreviousData, true); // keepPreviousData is active
      expect(lastResult?.isFetching, true);

      // Finish loading page 2
      await tester.pump(const Duration(milliseconds: 50));
      expect(lastResult?.data, 'Data for page 2');
      expect(lastResult?.isPreviousData, false);
      expect(lastResult?.isFetching, false);

      await tester.pumpWidget(const SizedBox());
      client.clear();
    });
  });
}
