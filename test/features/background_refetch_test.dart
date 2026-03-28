import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/smart_query.dart';

// Fake connectivity observer for testing
class FakeConnectivityObserver implements ConnectivityObserver {
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  @override
  Stream<ConnectivityStatus> get onStatusChanged => _controller.stream;

  @override
  Future<ConnectivityStatus> get currentStatus async =>
      ConnectivityStatus.online;

  void simulate(ConnectivityStatus status) {
    _controller.add(status);
  }
}

void main() {
  group('Background Refetch', () {
    testWidgets('stale query refetches on AppLifecycleState.resumed',
        (tester) async {
      int fetchCount = 0;
      final client = QueryClient();

      await tester.pumpWidget(
        QueryClientProvider(
          client: client,
          child: QueryBuilder<String>(
            queryKey: const ['refetch_test'],
            staleTime: const Duration(milliseconds: 10),
            fetcher: () async {
              fetchCount++;
              return 'data $fetchCount';
            },
            builder: (context, result) => const SizedBox.shrink(),
          ),
        ),
      );

      // Initial fetch
      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      // Wait for staleTime to expire
      await Future<void>.delayed(const Duration(milliseconds: 20));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Pumping frame so the 500ms debounce can pass...
      // Wait, our implementation of AppLifecycleObserver has a 500ms debounce!
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(fetchCount, 2); // Refetched!
    });

    testWidgets('fresh query does NOT refetch on AppLifecycleState.resumed',
        (tester) async {
      int fetchCount = 0;
      final client = QueryClient();

      await tester.pumpWidget(
        QueryClientProvider(
          client: client,
          child: QueryBuilder<String>(
            queryKey: const ['refetch_fresh'],
            staleTime: const Duration(minutes: 5), // Long stale time
            fetcher: () async {
              fetchCount++;
              return 'data $fetchCount';
            },
            builder: (context, result) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500)); // debounce
      await tester.pumpAndSettle();

      expect(fetchCount, 1); // Still 1! Data was fresh.
    });

    testWidgets('refetchOnWindowFocus: false prevents refetch on resume',
        (tester) async {
      int fetchCount = 0;
      final client = QueryClient();

      await tester.pumpWidget(
        QueryClientProvider(
          client: client,
          child: QueryBuilder<String>(
            queryKey: const ['refetch_disabled'],
            staleTime: Duration.zero,
            refetchOnWindowFocus: false, // Disabled!
            fetcher: () async {
              fetchCount++;
              return 'data $fetchCount';
            },
            builder: (context, result) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('refetch triggered on connectivity restored', () {
      fakeAsync((async) {
        int fetchCount = 0;
        final connectivity = FakeConnectivityObserver();
        final client = QueryClient(
          connectivityObserver: connectivity,
        );

        final options = QueryOptions<String>(
          key: const ['connectivity'],
          staleTime: Duration.zero,
          fetcher: () async {
            fetchCount++;
            return 'data';
          },
        );

        final query = client.cache.getOrCreate(['connectivity'], options);
        query.addObserver();
        query.fetch();

        async.flushMicrotasks();
        expect(fetchCount, 1);

        // Make data stale (duration zero makes it already stale, but advance time to be sure)
        async.elapse(const Duration(seconds: 1));

        // Simulate reconnect
        connectivity.simulate(ConnectivityStatus.online);
        async.flushMicrotasks();

        // The query should refetch
        expect(fetchCount, 2);
      });
    });

    test('polling (refetchInterval) fires at correct intervals', () {
      fakeAsync((async) {
        int fetchCount = 0;
        final client = QueryClient();

        final options = QueryOptions<String>(
          key: const ['polling'],
          refetchInterval: const Duration(seconds: 5),
          fetcher: () async {
            fetchCount++;
            return 'data';
          },
        );

        final query = client.cache.getOrCreate(['polling'], options);
        query.addObserver();
        query.fetch(); // initial fetch = 1

        async.flushMicrotasks();
        expect(fetchCount, 1);

        // Elapse 5 seconds
        async.elapse(const Duration(seconds: 5));
        expect(fetchCount, 2);

        // Elapse another 5 seconds
        async.elapse(const Duration(seconds: 5));
        expect(fetchCount, 3);
      });
    });

    test(
        'polling stops when observer count drops to 0 and resumes when it returns',
        () {
      fakeAsync((async) {
        int fetchCount = 0;
        final client = QueryClient();

        final options = QueryOptions<String>(
          key: const ['polling2'],
          refetchInterval: const Duration(seconds: 5),
          fetcher: () async {
            fetchCount++;
            return 'data';
          },
        );

        final query = client.cache.getOrCreate(['polling2'], options);
        query.addObserver(); // count = 1
        query.fetch();
        async.flushMicrotasks();
        expect(fetchCount, 1);

        query.removeObserver(); // count = 0, timer should stop

        async.elapse(const Duration(seconds: 10));
        // Should NOT have fetched again
        expect(fetchCount, 1);

        query.addObserver(); // count = 1, timer starts again
        async.elapse(const Duration(seconds: 5));
        expect(fetchCount, 2); // Fetched!
      });
    });
  });
}
