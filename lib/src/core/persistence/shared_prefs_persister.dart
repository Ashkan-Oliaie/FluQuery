import 'dart:convert';

import 'persisted_query.dart';
import 'persister.dart';

/// Adapter interface for SharedPreferences
abstract class SharedPrefsAdapter {
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

/// SharedPreferences-based persister
class SharedPrefsPersister implements Persister {
  static const _prefix = 'fluquery_';
  static const _indexKey = '${_prefix}index';

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
  Future<void> close() async {}
}
