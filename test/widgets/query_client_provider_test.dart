import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_query/smart_query.dart';

void main() {
  testWidgets('QueryClientProvider provides QueryClient to subtree',
      (tester) async {
    final client = QueryClient();
    QueryClient? providedClient;

    await tester.pumpWidget(
      QueryClientProvider(
        client: client,
        child: Builder(
          builder: (context) {
            providedClient = QueryClient.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(providedClient, equals(client));
  });

  testWidgets(
      'QueryClientProvider.updateShouldNotify returns false for identical client',
      (tester) async {
    final client = QueryClient();
    int buildCount = 0;

    final widget = QueryClientProvider(
      client: client,
      child: Builder(
        builder: (context) {
          QueryClient.of(context); // depend on it
          buildCount++;
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(widget);
    expect(buildCount, 1);

    // Rebuild with SAME client instance
    await tester.pumpWidget(widget);
    expect(buildCount, 1); // Should not rebuild child
  });

  testWidgets(
      'QueryClientProvider.updateShouldNotify returns true for different client',
      (tester) async {
    final client1 = QueryClient();
    final client2 = QueryClient();
    int buildCount = 0;

    await tester.pumpWidget(
      QueryClientProvider(
        client: client1,
        child: Builder(
          builder: (context) {
            QueryClient.of(context); // depend on it
            buildCount++;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(buildCount, 1);

    // Rebuild with DIFFERENT client instance
    await tester.pumpWidget(
      QueryClientProvider(
        client: client2,
        child: Builder(
          builder: (context) {
            QueryClient.of(context);
            buildCount++;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(buildCount, 2); // Should rebuild child
  });
}
