import 'package:flutter/widgets.dart';

import '../core/query_client.dart';
import '../observers/app_lifecycle_observer.dart';

/// Provides a [QueryClient] to the widget subtree.
///
/// Wrap your app with this widget to make [QueryClient] accessible via
/// `QueryClient.of(context)` from any descendant widget.
///
/// ```dart
/// void main() {
///   runApp(
///     QueryClientProvider(
///       client: QueryClient(),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class QueryClientProvider extends StatefulWidget {
  /// Creates a [QueryClientProvider].
  const QueryClientProvider({
    super.key,
    required this.client,
    required this.child,
  });

  /// The [QueryClient] to provide to descendants.
  final QueryClient client;

  /// The widget below this in the tree.
  final Widget child;

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  late final AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(widget.client);
    _lifecycleObserver.register();
  }

  @override
  void dispose() {
    _lifecycleObserver.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QueryClientInherited(
      client: widget.client,
      child: widget.child,
    );
  }
}

/// InheritedWidget that holds the [QueryClient].
///
/// Used internally by [QueryClientProvider] and [QueryClient.of].
class QueryClientInherited extends InheritedWidget {
  /// Creates a [QueryClientInherited].
  const QueryClientInherited({
    super.key,
    required this.client,
    required super.child,
  });

  /// The provided [QueryClient].
  final QueryClient client;

  @override
  bool updateShouldNotify(QueryClientInherited oldWidget) {
    // Only rebuild if the client INSTANCE changes, not on every query update.
    return client != oldWidget.client;
  }
}
