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

  testWidgets('QueryBuilder renders loading then success', (tester) async {
    int buildCount = 0;

    await tester.pumpWidget(
      QueryClientProvider(
        client: client,
        child: MaterialApp(
          home: Scaffold(
            body: QueryBuilder<String>(
              queryKey: const ['test'],
              fetcher: () async {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return 'Hello World';
              },
              builder: (context, result) {
                buildCount++;
                if (result.isLoading) {
                  return const Text('Loading...');
                }
                return Text('Data: ${result.data}');
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump(); // Flush the microtask that updates to loading
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Data: Hello World'), findsOneWidget);
    expect(buildCount, 3); // idle -> loading -> success

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
    client.clear();
  });

  testWidgets('QueryBuilder re-subscribes when queryKey changes',
      (tester) async {
    String currentKey = 'first';

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return QueryClientProvider(
            client: client,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    QueryBuilder<String>(
                      queryKey: ['test', currentKey],
                      fetcher: () async => 'Data for $currentKey',
                      builder: (context, result) {
                        return Text('Result: ${result.data ?? "loading"}');
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          currentKey = 'second';
                        });
                      },
                      child: const Text('Change Key'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Result: Data for first'), findsOneWidget);

    // Tap button to change key
    await tester.tap(find.text('Change Key'));
    await tester.pump(); // Start rebuild

    expect(find.text('Result: loading'), findsOneWidget); // Loading new key
    await tester.pumpAndSettle(); // Finish fetch
    expect(find.text('Result: Data for second'), findsOneWidget);

    // Ensure the old query observer count went down to 0
    final oldQuery = client.cache.get(['test', 'first']);
    expect(oldQuery?.observerCount, 0);

    final newQuery = client.cache.get(['test', 'second']);
    expect(newQuery?.observerCount, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
    client.clear();
  });
}
