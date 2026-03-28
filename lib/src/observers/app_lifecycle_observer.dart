import 'package:flutter/widgets.dart';

import '../core/query_client.dart';

/// Observes app lifecycle changes and triggers refetching of stale queries
/// when the app resumes from the background.
///
/// This observer:
/// - Only responds to [AppLifecycleState.resumed]
/// - Ignores [AppLifecycleState.inactive] (iOS control center, notification center)
/// - Debounces rapid paused→resumed transitions (Android rotation)
class AppLifecycleObserver with WidgetsBindingObserver {
  /// Creates an app lifecycle observer for the given [QueryClient].
  AppLifecycleObserver(this._client);

  final QueryClient _client;
  DateTime? _lastRefetchTime;

  /// Minimum time between refetches (guards against Android rotation
  /// which fires paused→resumed rapidly).
  static const Duration _debounceInterval = Duration(milliseconds: 500);

  /// Registers this observer with the Flutter binding.
  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Unregisters this observer from the Flutter binding.
  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Debounce: skip if we just refetched (e.g., Android rotation).
    final now = DateTime.now();
    if (_lastRefetchTime != null &&
        now.difference(_lastRefetchTime!) < _debounceInterval) {
      return;
    }
    _lastRefetchTime = now;

    // Refetch all stale queries that have active observers.
    _client.refetchStaleActiveQueries(respectRefetchOnWindowFocus: true);
  }
}
