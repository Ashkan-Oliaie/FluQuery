/// Configuration for how long unused query data stays in cache
///
/// When a query has no active observers (no widgets using it),
/// this duration determines how long the cached data is kept
/// before being garbage collected.
///
/// Use cases:
/// - Keep data for quick navigation back to a page
/// - Free memory by removing unused data
/// - Balance memory usage vs. user experience
///
/// Note: This is different from [StaleTime]:
/// - StaleTime: When to refetch (data freshness)
/// - CacheTime: When to remove from memory (garbage collection)
///
/// Example:
/// ```dart
/// useQuery(
///   queryKey: ['todos'],
///   queryFn: fetchTodos,
///   cacheTime: CacheTime(Duration(minutes: 10)), // Keep 10 min after unmount
/// );
/// ```
class CacheTime {
  /// The duration to keep data after last observer unsubscribes
  final Duration duration;

  const CacheTime(this.duration);

  /// Remove immediately when no observers (useful for sensitive data)
  static const CacheTime zero = CacheTime(Duration.zero);

  /// Default: keep for 5 minutes after last observer
  static const CacheTime defaultTime = CacheTime(Duration(minutes: 5));

  /// Never remove automatically (stays until manually cleared)
  static const CacheTime infinity = CacheTime(Duration(days: 365 * 100));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheTime && duration == other.duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'CacheTime(${duration.inSeconds}s)';
}

/// @deprecated Use [CacheTime] instead. Will be removed in v2.0.0.
@Deprecated('Use CacheTime instead')
typedef GcTime = CacheTime;
