import 'dart:async';

/// Network connectivity status.
enum ConnectivityStatus {
  /// Device is connected to a network.
  online,

  /// Device has no network connection.
  offline,
}

/// Abstract interface for monitoring network connectivity.
///
/// Implement this with your preferred connectivity package (e.g.,
/// `connectivity_plus`) and pass it to [QueryClient].
///
/// ```dart
/// class ConnectivityPlusObserver implements ConnectivityObserver {
///   final _connectivity = Connectivity();
///
///   @override
///   Stream<ConnectivityStatus> get onStatusChanged {
///     return _connectivity.onConnectivityChanged.map((result) {
///       return result == ConnectivityResult.none
///           ? ConnectivityStatus.offline
///           : ConnectivityStatus.online;
///     });
///   }
///
///   @override
///   Future<ConnectivityStatus> get currentStatus async {
///     final result = await _connectivity.checkConnectivity();
///     return result == ConnectivityResult.none
///         ? ConnectivityStatus.offline
///         : ConnectivityStatus.online;
///   }
/// }
/// ```
abstract class ConnectivityObserver {
  /// Stream of connectivity status changes.
  Stream<ConnectivityStatus> get onStatusChanged;

  /// The current connectivity status.
  Future<ConnectivityStatus> get currentStatus;
}
