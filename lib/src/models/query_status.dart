/// Status states for a query's lifecycle.
///
/// The query state machine transitions between these states:
/// - [idle] → Query is disabled or has never fetched
/// - [loading] → First fetch in progress, no data yet
/// - [success] → Data loaded successfully
/// - [error] → Fetch failed after exhausting retries
/// - [refreshing] → Has cached data, fetching updated data in background
enum QueryStatus {
  /// Query is disabled (`enabled: false`) or has never been triggered.
  idle,

  /// No data yet, fetch in progress. Show a full loading spinner.
  loading,

  /// Data loaded successfully.
  success,

  /// Fetch failed. Previous data may still be available.
  error,

  /// Has cached data, fetching updated data in background.
  /// Show old data with a subtle loading indicator.
  refreshing,
}

/// Status states for a mutation's lifecycle.
enum MutationStatus {
  /// Mutation has not been triggered yet, or has been reset.
  idle,

  /// Mutation is in progress.
  loading,

  /// Mutation completed successfully.
  success,

  /// Mutation failed.
  error,
}
