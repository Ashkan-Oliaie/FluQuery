import 'dart:async';
import 'dart:convert';

import 'types.dart';

/// A persisted query entry that can be serialized/deserialized
class PersistedQuery {
  /// The query key
  final QueryKey queryKey;

  /// The query hash (for quick lookup)
  final String queryHash;

  /// Serialized data (JSON string or Map)
  final dynamic serializedData;

  /// When the data was last updated
  final DateTime? dataUpdatedAt;

  /// When this entry was persisted
  final DateTime persistedAt;

  /// Query status when persisted
  final String status;

  const PersistedQuery({
    required this.queryKey,
    required this.queryHash,
    required this.serializedData,
    this.dataUpdatedAt,
    required this.persistedAt,
    required this.status,
  });

  /// Convert to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'queryKey': queryKey,
        'queryHash': queryHash,
        'serializedData': serializedData,
        'dataUpdatedAt': dataUpdatedAt?.toIso8601String(),
        'persistedAt': persistedAt.toIso8601String(),
        'status': status,
      };

  /// Create from JSON map
  factory PersistedQuery.fromJson(Map<String, dynamic> json) {
    return PersistedQuery(
      queryKey: (json['queryKey'] as List).cast<dynamic>(),
      queryHash: json['queryHash'] as String,
      serializedData: json['serializedData'],
      dataUpdatedAt: json['dataUpdatedAt'] != null
          ? DateTime.parse(json['dataUpdatedAt'] as String)
          : null,
      persistedAt: DateTime.parse(json['persistedAt'] as String),
      status: json['status'] as String,
    );
  }
}

/// Serializer interface for converting data to/from persistable format
/// Users must implement this for each data type they want to persist
abstract class QueryDataSerializer<TData> {
  /// Serialize data to a JSON-compatible format
  dynamic serialize(TData data);

  /// Deserialize data from a JSON-compatible format
  TData deserialize(dynamic json);
}

/// Simple JSON serializer for data that's already JSON-compatible
/// Works with Map, List, String, int, double, bool, null
class JsonSerializer<TData> implements QueryDataSerializer<TData> {
  const JsonSerializer();

  @override
  dynamic serialize(TData data) => data;

  @override
  TData deserialize(dynamic json) {
    final dynamic d = json;
    return d;
  }
}

/// Serializer for List<Map> data (common for API responses)
class ListMapSerializer implements QueryDataSerializer<List<Map<String, dynamic>>> {
  const ListMapSerializer();

  @override
  dynamic serialize(List<Map<String, dynamic>> data) => data;

  @override
  List<Map<String, dynamic>> deserialize(dynamic json) {
    return (json as List).cast<Map<String, dynamic>>();
  }
}

/// Options for query persistence
class PersistOptions<TData> {
  /// Serializer for the query data
  final QueryDataSerializer<TData> serializer;

  /// Maximum age of persisted data before it's considered expired
  /// If null, persisted data never expires (but still respects staleTime)
  final Duration? maxAge;

  /// Whether to persist error states
  final bool persistErrors;

  /// Custom storage key prefix (defaults to query hash)
  final String? keyPrefix;

  const PersistOptions({
    required this.serializer,
    this.maxAge,
    this.persistErrors = false,
    this.keyPrefix,
  });
}

/// Abstract persister interface - implement this for different storage backends
/// 
/// Built-in implementations:
/// - [InMemoryPersister] - For testing (included in core)
/// - HivePersister - For production (separate package: fluquery_hive)
/// 
/// The persister is responsible for:
/// 1. Storing query data when queries succeed
/// 2. Retrieving stored data on app startup
/// 3. Removing expired or invalidated data
abstract class Persister {
  /// Initialize the persister (open database, etc.)
  Future<void> init();

  /// Persist a query
  Future<void> persistQuery(PersistedQuery query);

  /// Restore a single query by hash
  Future<PersistedQuery?> restoreQuery(String queryHash);

  /// Restore all persisted queries
  Future<List<PersistedQuery>> restoreAll();

  /// Remove a query from persistence
  Future<void> removeQuery(String queryHash);

  /// Remove queries matching a filter
  Future<void> removeQueries(bool Function(PersistedQuery) filter);

  /// Clear all persisted queries
  Future<void> clear();

  /// Close the persister and release resources
  Future<void> close();
}

/// In-memory persister for testing purposes
class InMemoryPersister implements Persister {
  final Map<String, PersistedQuery> _storage = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> persistQuery(PersistedQuery query) async {
    _storage[query.queryHash] = query;
  }

  @override
  Future<PersistedQuery?> restoreQuery(String queryHash) async {
    return _storage[queryHash];
  }

  @override
  Future<List<PersistedQuery>> restoreAll() async {
    return _storage.values.toList();
  }

  @override
  Future<void> removeQuery(String queryHash) async {
    _storage.remove(queryHash);
  }

  @override
  Future<void> removeQueries(bool Function(PersistedQuery) filter) async {
    _storage.removeWhere((_, query) => filter(query));
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> close() async {}
}

/// Shared Preferences persister for simple persistence needs
/// Uses JSON encoding to store data as strings
class SharedPrefsPersister implements Persister {
  static const _prefix = 'fluquery_';
  static const _indexKey = '${_prefix}index';

  /// The getter for SharedPreferences instance
  /// This allows lazy initialization and avoids direct dependency
  final Future<SharedPrefsAdapter> Function() getPrefs;

  SharedPrefsAdapter? _prefs;
  Set<String> _index = {};

  SharedPrefsPersister({required this.getPrefs});

  @override
  Future<void> init() async {
    _prefs = await getPrefs();
    final indexJson = _prefs!.getString(_indexKey);
    if (indexJson != null) {
      _index = Set<String>.from(jsonDecode(indexJson) as List);
    }
  }

  Future<void> _saveIndex() async {
    await _prefs!.setString(_indexKey, jsonEncode(_index.toList()));
  }

  @override
  Future<void> persistQuery(PersistedQuery query) async {
    final key = '$_prefix${query.queryHash}';
    await _prefs!.setString(key, jsonEncode(query.toJson()));
    _index.add(query.queryHash);
    await _saveIndex();
  }

  @override
  Future<PersistedQuery?> restoreQuery(String queryHash) async {
    final key = '$_prefix$queryHash';
    final json = _prefs!.getString(key);
    if (json == null) return null;
    return PersistedQuery.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  @override
  Future<List<PersistedQuery>> restoreAll() async {
    final results = <PersistedQuery>[];
    for (final hash in _index) {
      final query = await restoreQuery(hash);
      if (query != null) results.add(query);
    }
    return results;
  }

  @override
  Future<void> removeQuery(String queryHash) async {
    final key = '$_prefix$queryHash';
    await _prefs!.remove(key);
    _index.remove(queryHash);
    await _saveIndex();
  }

  @override
  Future<void> removeQueries(bool Function(PersistedQuery) filter) async {
    final toRemove = <String>[];
    for (final hash in _index) {
      final query = await restoreQuery(hash);
      if (query != null && filter(query)) {
        toRemove.add(hash);
      }
    }
    for (final hash in toRemove) {
      await removeQuery(hash);
    }
  }

  @override
  Future<void> clear() async {
    for (final hash in _index.toList()) {
      await _prefs!.remove('$_prefix$hash');
    }
    _index.clear();
    await _prefs!.remove(_indexKey);
  }

  @override
  Future<void> close() async {
    // SharedPreferences doesn't need explicit closing
  }
}

/// Adapter interface for SharedPreferences
/// This allows using SharedPreferences without a direct dependency
abstract class SharedPrefsAdapter {
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

