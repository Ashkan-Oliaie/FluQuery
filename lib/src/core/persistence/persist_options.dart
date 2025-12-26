import 'serializers.dart';

/// Options for query persistence
///
/// Example:
/// ```dart
/// useQuery(
///   queryKey: ['todos'],
///   queryFn: fetchTodos,
///   persist: PersistOptions<List<Todo>>(
///     serializer: TodoListSerializer(),
///     maxAge: Duration(days: 7),
///   ),
/// );
/// ```
class PersistOptions<TData> {
  /// Serializer to convert data to/from JSON-compatible format.
  ///
  /// **Schema changes:** If your data model changes between app versions
  /// (e.g., a field is added/removed), deserialization may fail.
  /// FluQuery handles this gracefully by discarding corrupted data
  /// and triggering a fresh fetch. No migration is required.
  final QueryDataSerializer<TData> serializer;

  /// Maximum age of persisted data.
  /// Data older than this will be discarded on hydration.
  /// If null, data never expires (unless manually cleared).
  final Duration? maxAge;

  /// Whether to persist error state alongside data.
  /// Default: false (only success data is persisted).
  ///
  /// When true, the last error is also saved. On hydration:
  /// - If data exists, it's restored (even if there was an error)
  /// - The error state is NOT restored (query starts fresh)
  ///
  /// This is useful for offline scenarios where you want to show
  /// stale data even if the last fetch failed.
  final bool persistErrors;

  /// Key prefix for namespacing persisted queries.
  /// Useful for multi-tenant apps or feature isolation.
  ///
  /// Example: With keyPrefix 'user_123', query ['todos'] becomes
  /// persisted under 'user_123:todos' internally.
  final String? keyPrefix;

  /// Whether to remove persisted data if deserialization fails.
  /// Default: true (corrupted/outdated data is automatically cleaned up).
  ///
  /// This handles schema changes gracefully - if your data model
  /// changes between app versions, the old data is simply discarded
  /// and a fresh fetch occurs.
  final bool removeOnDeserializationError;

  const PersistOptions({
    required this.serializer,
    this.maxAge,
    this.persistErrors = false,
    this.keyPrefix,
    this.removeOnDeserializationError = true,
  });

  /// Get the effective persistence key for a query hash.
  /// Applies keyPrefix if set.
  String getEffectiveHash(String queryHash) {
    if (keyPrefix == null || keyPrefix!.isEmpty) {
      return queryHash;
    }
    return '$keyPrefix:$queryHash';
  }
}
