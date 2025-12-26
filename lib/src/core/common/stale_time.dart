/// Configuration for when data is considered stale
///
/// Stale data will be refetched in the background when accessed.
/// Fresh data will be returned immediately without refetching.
///
/// Example:
/// ```dart
/// useQuery(
///   queryKey: ['todos'],
///   queryFn: fetchTodos,
///   staleTime: StaleTime(Duration(minutes: 5)), // Fresh for 5 minutes
/// );
/// ```
class StaleTime {
  /// The duration after which data becomes stale
  final Duration duration;

  const StaleTime(this.duration);

  /// Data is immediately stale (always refetch)
  static const StaleTime zero = StaleTime(Duration.zero);

  /// Data is never stale (never auto-refetch)
  static const StaleTime infinity = StaleTime(Duration(days: 365 * 100));

  /// Check if data is stale based on when it was last updated
  bool isStale(DateTime dataUpdatedAt) {
    if (this == infinity) return false;
    return DateTime.now().difference(dataUpdatedAt) > duration;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaleTime && duration == other.duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'StaleTime(${duration.inSeconds}s)';
}
