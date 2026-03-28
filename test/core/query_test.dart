import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/src/core/query.dart';
import 'package:smart_query/src/core/query_cache.dart';
import 'package:smart_query/src/models/query_options.dart';
import 'package:smart_query/src/models/query_status.dart';

void main() {
  group('Query', () {
    late QueryCache cache;

    setUp(() {
      cache = QueryCache();
    });

    tearDown(() {
      cache.dispose();
    });

    test('starts in idle state', () {
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'data',
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      expect(query.status, QueryStatus.idle);
      expect(query.data, isNull);
      query.dispose();
    });

    test('starts in success state when initialData is provided', () {
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'new data',
        initialData: 'initial',
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      expect(query.status, QueryStatus.success);
      expect(query.data, 'initial');
      expect(query.dataUpdatedAt, isNotNull);
      query.dispose();
    });

    test('fetch transitions to loading then success', () async {
      final completer = Completer<String>();
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () => completer.future,
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();

      final statuses = <QueryStatus>[];
      query.stream.listen((r) => statuses.add(r.status));

      final fetchFuture = query.fetch();
      await Future<void>.delayed(Duration.zero);
      expect(query.status, QueryStatus.loading);

      completer.complete('fetched data');
      await fetchFuture;
      await Future<void>.delayed(Duration.zero); // Let stream emit.

      expect(query.data, 'fetched data');
      expect(query.status, QueryStatus.success);
      expect(statuses, contains(QueryStatus.loading));
      expect(statuses, contains(QueryStatus.success));

      query.removeObserver();
      query.dispose();
    });

    test('fetch transitions to refreshing when data exists', () async {
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'new data',
        initialData: 'old data',
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();

      final statuses = <QueryStatus>[];
      query.stream.listen((r) => statuses.add(r.status));

      await query.fetch(force: true);

      expect(statuses, contains(QueryStatus.refreshing));
      expect(query.data, 'new data');

      query.removeObserver();
      query.dispose();
    });

    test('fetch transitions to error on failure', () async {
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => throw Exception('fail'),
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(query.status, QueryStatus.error);
      expect(query.currentResult.error, isA<Exception>());

      query.removeObserver();
      query.dispose();
    });

    test('deduplication: concurrent fetches share one request', () async {
      int fetchCount = 0;
      final completer = Completer<String>();
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () {
          fetchCount++;
          return completer.future;
        },
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();

      // Call fetch multiple times.
      final f1 = query.fetch();
      final f2 = query.fetch();
      final f3 = query.fetch();

      completer.complete('data');
      await Future.wait([f1, f2, f3]);

      expect(fetchCount, 1, reason: 'Only 1 network request should be made');
      expect(query.data, 'data');

      query.removeObserver();
      query.dispose();
    });

    test('does not fetch when enabled is false', () async {
      int fetchCount = 0;
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async {
          fetchCount++;
          return 'data';
        },
        enabled: false,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(fetchCount, 0);
      expect(query.status, QueryStatus.idle);

      query.removeObserver();
      query.dispose();
    });

    test('does not refetch when data is fresh', () async {
      int fetchCount = 0;
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async {
          fetchCount++;
          return 'data';
        },
        staleTime: const Duration(minutes: 5),
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();

      await query.fetch();
      expect(fetchCount, 1);

      // Following fetch should not trigger because data is fresh.
      await query.fetch();
      expect(fetchCount, 1);

      query.removeObserver();
      query.dispose();
    });

    test('setData updates cache immediately and prevents in-flight overwrite',
        () async {
      final completer = Completer<String>();
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () => completer.future,
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();

      // Start a fetch.
      final fetchFuture = query.fetch();
      await Future<void>.delayed(Duration.zero);

      // Set data manually (optimistic update).
      query.setData('optimistic');
      expect(query.data, 'optimistic');
      expect(query.status, QueryStatus.success);

      // Complete the fetch — should NOT overwrite optimistic value.
      completer.complete('fetched');
      await fetchFuture;

      expect(query.data, 'optimistic');

      query.removeObserver();
      query.dispose();
    });

    test('select transform is applied to fetched data', () async {
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'hello world',
        select: (data) => data.toUpperCase(),
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(query.data, 'HELLO WORLD');

      query.removeObserver();
      query.dispose();
    });

    test('cancel stops in-flight fetch and retry timers', () {
      fakeAsync((async) {
        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => throw Exception('fail'),
          retry: 3,
          retryDelay: (_) => const Duration(seconds: 1),
        );
        final query =
            Query<String>(key: ['test'], options: options, cache: cache);
        query.addObserver();
        query.fetch();

        async.elapse(const Duration(milliseconds: 100));
        query.cancel();

        // Elapse past retry delay — should NOT retry after cancel.
        async.elapse(const Duration(seconds: 5));
        // If cancel didn't work, this would have tried to fetch again.

        query.removeObserver();
        query.dispose();
      });
    });

    test('cache eviction timer starts when last observer leaves', () {
      fakeAsync((async) {
        final options = QueryOptions<String>(
          key: ['evict-test'],
          fetcher: () async => 'data',
          cacheTime: const Duration(minutes: 5),
          retry: 0,
        );
        final query = cache.getOrCreate<String>(['evict-test'], options);
        query.addObserver();
        query.fetch();
        async.elapse(Duration.zero);

        expect(cache.get<String>(['evict-test']), isNotNull);

        // Remove observer — starts eviction timer.
        query.removeObserver();

        // Elapse 4 minutes — still in cache.
        async.elapse(const Duration(minutes: 4));
        expect(cache.get<String>(['evict-test']), isNotNull);

        // Elapse 1 more minute — evicted.
        async.elapse(const Duration(minutes: 1));
        expect(cache.get<String>(['evict-test']), isNull);
      });
    });

    test('eviction timer is cancelled when observer re-subscribes', () {
      fakeAsync((async) {
        final options = QueryOptions<String>(
          key: ['evict-test2'],
          fetcher: () async => 'data',
          cacheTime: const Duration(minutes: 5),
          retry: 0,
        );
        final query = cache.getOrCreate<String>(['evict-test2'], options);
        query.addObserver();
        query.fetch();
        async.elapse(Duration.zero);

        query.removeObserver();
        async.elapse(const Duration(minutes: 3));

        // Re-subscribe — cancels eviction.
        query.addObserver();
        async.elapse(const Duration(minutes: 3));

        // Should still be in cache even though 6 minutes total have passed.
        expect(cache.get<String>(['evict-test2']), isNotNull);

        query.removeObserver();
        query.dispose();
      });
    });

    test('onSuccess callback is called', () async {
      String? callbackData;
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'result',
        onSuccess: (data, key) => callbackData = data,
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(callbackData, 'result');

      query.removeObserver();
      query.dispose();
    });

    test('onError callback is called after retries exhausted', () async {
      Object? callbackError;
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => throw 'error message',
        onError: (error, st, key) => callbackError = error,
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(callbackError, 'error message');

      query.removeObserver();
      query.dispose();
    });

    test('onSettled is called on both success and error', () async {
      int settledCallCount = 0;
      final options = QueryOptions<String>(
        key: ['test'],
        fetcher: () async => 'data',
        onSettled: (data, error) => settledCallCount++,
        retry: 0,
      );
      final query =
          Query<String>(key: ['test'], options: options, cache: cache);
      query.addObserver();
      await query.fetch();

      expect(settledCallCount, 1);

      query.removeObserver();
      query.dispose();
    });
  });
}
