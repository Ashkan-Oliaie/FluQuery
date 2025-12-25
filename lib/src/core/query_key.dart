import 'package:collection/collection.dart';
import 'types.dart';

/// Utilities for working with query keys
class QueryKeyUtils {
  const QueryKeyUtils._();

  /// Create a query key from a string
  static QueryKey from(dynamic key) {
    if (key is QueryKey) return key;
    if (key is String) return [key];
    if (key is List) return key;
    return [key];
  }

  /// Hash a query key for use as a cache key
  static String hashKey(QueryKey key) {
    return _serializeKey(key);
  }

  /// Check if two query keys are equal
  static bool equals(QueryKey a, QueryKey b) {
    return const DeepCollectionEquality().equals(a, b);
  }

  /// Check if a query key matches a filter
  static bool matchesFilter(QueryKey key, QueryKey filter) {
    if (filter.isEmpty) return true;
    if (key.length < filter.length) return false;

    for (var i = 0; i < filter.length; i++) {
      if (!const DeepCollectionEquality().equals(key[i], filter[i])) {
        return false;
      }
    }
    return true;
  }

  /// Serialize a query key to a string
  static String _serializeKey(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return '[${value.map(_serializeKey).join(',')}]';
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return '{${entries.map((e) => '${_serializeKey(e.key)}:${_serializeKey(e.value)}').join(',')}}';
    }
    return value.toString();
  }
}

