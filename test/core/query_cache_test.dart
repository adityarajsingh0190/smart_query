import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/src/core/query_cache.dart';
import 'package:smart_query/src/models/query_options.dart';

void main() {
  group('QueryCache', () {
    late QueryCache cache;

    setUp(() {
      cache = QueryCache();
    });

    tearDown(() {
      cache.dispose();
    });

    group('key serialization', () {
      test('simple key produces consistent string', () {
        final key = ['user'];
        expect(QueryCache.serializeKey(key), '["user"]');
      });

      test('key with parameters', () {
        final key = ['user', 42];
        expect(QueryCache.serializeKey(key), '["user",42]');
      });

      test('key with nested list', () {
        final key = ['user', 42, 'posts'];
        expect(QueryCache.serializeKey(key), '["user",42,"posts"]');
      });

      test('key with Map produces sorted keys', () {
        final key1 = [
          'products',
          {'page': 1, 'filter': 'active'}
        ];
        final key2 = [
          'products',
          {'filter': 'active', 'page': 1}
        ];
        final s1 = QueryCache.serializeKey(key1);
        final s2 = QueryCache.serializeKey(key2);
        expect(s1, s2,
            reason: 'Map keys should be sorted before serialization');
      });

      test('different value types are NOT equal', () {
        // ['user', 1] and ['user', '1'] are intentionally different
        final key1 = ['user', 1];
        final key2 = ['user', '1'];
        expect(
          QueryCache.serializeKey(key1),
          isNot(QueryCache.serializeKey(key2)),
        );
      });
    });

    group('getOrCreate', () {
      test('creates a new query when key does not exist', () {
        int fetchCount = 0;
        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async {
            fetchCount++;
            return 'data';
          },
        );

        final query = cache.getOrCreate<String>(['test'], options);
        expect(query, isNotNull);
        expect(cache.queries.length, 1);
        expect(fetchCount, 0);
      });

      test('returns same query for same key', () {
        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => 'data',
        );

        final q1 = cache.getOrCreate<String>(['test'], options);
        final q2 = cache.getOrCreate<String>(['test'], options);
        expect(identical(q1, q2), isTrue);
        expect(cache.queries.length, 1);
      });

      test('creates different queries for different keys', () {
        final options1 = QueryOptions<String>(
          key: ['test1'],
          fetcher: () async => 'data1',
        );
        final options2 = QueryOptions<String>(
          key: ['test2'],
          fetcher: () async => 'data2',
        );

        cache.getOrCreate<String>(['test1'], options1);
        cache.getOrCreate<String>(['test2'], options2);
        expect(cache.queries.length, 2);
      });
    });

    group('get', () {
      test('returns null for non-existent key', () {
        expect(cache.get<String>(['non-existent']), isNull);
      });

      test('returns existing query', () {
        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => 'data',
        );
        cache.getOrCreate<String>(['test'], options);
        expect(cache.get<String>(['test']), isNotNull);
      });
    });

    group('remove', () {
      test('removes a query from cache', () {
        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => 'data',
        );
        cache.getOrCreate<String>(['test'], options);
        expect(cache.queries.length, 1);

        cache.remove(['test']);
        expect(cache.queries.length, 0);
        expect(cache.get<String>(['test']), isNull);
      });

      test('removing non-existent key does nothing', () {
        cache.remove(['non-existent']);
        expect(cache.queries.length, 0);
      });
    });

    group('clear', () {
      test('removes all queries', () {
        final options1 = QueryOptions<String>(
          key: ['test1'],
          fetcher: () async => 'data1',
        );
        final options2 = QueryOptions<String>(
          key: ['test2'],
          fetcher: () async => 'data2',
        );

        cache.getOrCreate<String>(['test1'], options1);
        cache.getOrCreate<String>(['test2'], options2);
        expect(cache.queries.length, 2);

        cache.clear();
        expect(cache.queries.length, 0);
      });
    });

    group('getQueriesByPrefix', () {
      test('returns all queries matching a prefix', () {
        final opts1 = QueryOptions<String>(
          key: ['user', 1],
          fetcher: () async => 'user1',
        );
        final opts2 = QueryOptions<String>(
          key: ['user', 2],
          fetcher: () async => 'user2',
        );
        final opts3 = QueryOptions<String>(
          key: ['posts'],
          fetcher: () async => 'posts',
        );

        cache.getOrCreate<String>(['user', 1], opts1);
        cache.getOrCreate<String>(['user', 2], opts2);
        cache.getOrCreate<String>(['posts'], opts3);

        final userQueries = cache.getQueriesByPrefix(['user']);
        expect(userQueries.length, 2);
      });

      test('exact match is included in prefix results', () {
        final opts = QueryOptions<String>(
          key: ['user'],
          fetcher: () async => 'user',
        );
        cache.getOrCreate<String>(['user'], opts);

        final results = cache.getQueriesByPrefix(['user']);
        expect(results.length, 1);
      });

      test('does not match unrelated keys', () {
        final opts = QueryOptions<String>(
          key: ['posts'],
          fetcher: () async => 'posts',
        );
        cache.getOrCreate<String>(['posts'], opts);

        final results = cache.getQueriesByPrefix(['user']);
        expect(results.length, 0);
      });
    });

    group('events', () {
      test('emits added event when query is created', () async {
        final events = <CacheEvent>[];
        cache.events.listen(events.add);

        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => 'data',
        );
        cache.getOrCreate<String>(['test'], options);

        await Future<void>.delayed(Duration.zero);
        expect(events.length, 1);
        expect(events.first.type, CacheEventType.added);
      });

      test('emits removed event when query is removed', () async {
        final events = <CacheEvent>[];

        final options = QueryOptions<String>(
          key: ['test'],
          fetcher: () async => 'data',
        );
        cache.getOrCreate<String>(['test'], options);

        cache.events.listen(events.add);
        cache.remove(['test']);

        await Future<void>.delayed(Duration.zero);
        expect(events.length, 1);
        expect(events.first.type, CacheEventType.removed);
      });
    });
  });
}
