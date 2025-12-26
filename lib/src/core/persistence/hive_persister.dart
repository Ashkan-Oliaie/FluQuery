import 'dart:convert';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../common/common.dart';
import 'persisted_query.dart';
import 'persister.dart';

/// Hive CE-based persister for production use.
///
/// Uses [Hive CE](https://pub.dev/packages/hive_ce) - the actively maintained
/// community edition of Hive for fast, encrypted local storage.
///
/// ## Basic Usage:
///
/// ```dart
/// import 'package:fluquery/fluquery.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Create and initialize the persister
///   final persister = HiveCePersister();
///   await persister.init();
///
///   // Create QueryClient with persister
///   final queryClient = QueryClient(persister: persister);
///
///   // Restore cached data
///   await queryClient.hydrate();
///
///   runApp(
///     QueryClientProvider(
///       client: queryClient,
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## Custom Box Name:
///
/// ```dart
/// final persister = HiveCePersister(boxName: 'my_app_cache');
/// ```
///
/// ## With Encryption:
///
/// ```dart
/// final encryptionKey = Hive.generateSecureKey();
/// final persister = HiveCePersister(
///   boxName: 'secure_cache',
///   encryptionCipher: HiveAesCipher(encryptionKey),
/// );
/// ```
class HiveCePersister implements Persister {
  /// The name of the Hive box to use for storage
  final String boxName;

  /// Optional encryption cipher for secure storage
  final HiveCipher? encryptionCipher;

  /// Optional custom path for storage (defaults to app documents directory)
  final String? path;

  Box<String>? _box;
  bool _isInitialized = false;

  /// Creates a new Hive CE persister.
  ///
  /// - [boxName]: Name of the Hive box (default: 'fluquery_cache')
  /// - [encryptionCipher]: Optional cipher for encrypted storage
  /// - [path]: Optional custom storage path
  HiveCePersister({
    this.boxName = 'fluquery_cache',
    this.encryptionCipher,
    this.path,
  });

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive for Flutter (handles path automatically)
      await Hive.initFlutter(path);

      // Open the box
      _box = await Hive.openBox<String>(
        boxName,
        encryptionCipher: encryptionCipher,
      );

      _isInitialized = true;
      FluQueryLogger.info(
          'HiveCePersister initialized: ${_box!.length} cached entries');
    } catch (e, st) {
      FluQueryLogger.error('Failed to initialize HiveCePersister', e, st);
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError(
          'HiveCePersister not initialized. Call init() before using.');
    }
  }

  @override
  Future<void> persistQuery(PersistedQuery query) async {
    _ensureInitialized();
    try {
      final json = jsonEncode(query.toJson());
      await _box!.put(query.queryHash, json);
      FluQueryLogger.debug('Persisted query: ${query.queryKey}');
    } catch (e, st) {
      FluQueryLogger.error('Failed to persist query ${query.queryKey}', e, st);
    }
  }

  @override
  Future<PersistedQuery?> restoreQuery(String queryHash) async {
    _ensureInitialized();
    try {
      final json = _box!.get(queryHash);
      if (json == null) return null;

      return PersistedQuery.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (e, st) {
      FluQueryLogger.error('Failed to restore query $queryHash', e, st);
      // Remove corrupted entry
      await _box!.delete(queryHash);
      return null;
    }
  }

  @override
  Future<List<PersistedQuery>> restoreAll() async {
    _ensureInitialized();
    final results = <PersistedQuery>[];

    for (final key in _box!.keys) {
      try {
        final json = _box!.get(key as String);
        if (json != null) {
          final query = PersistedQuery.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          results.add(query);
        }
      } catch (e) {
        // Skip and remove corrupted entries
        FluQueryLogger.warn('Removing corrupted cache entry: $key');
        await _box!.delete(key);
      }
    }

    return results;
  }

  @override
  Future<void> removeQuery(String queryHash) async {
    _ensureInitialized();
    await _box!.delete(queryHash);
    FluQueryLogger.debug('Removed persisted query: $queryHash');
  }

  @override
  Future<void> removeQueries(bool Function(PersistedQuery) filter) async {
    _ensureInitialized();
    final toRemove = <String>[];

    for (final key in _box!.keys) {
      try {
        final json = _box!.get(key as String);
        if (json != null) {
          final query = PersistedQuery.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          if (filter(query)) {
            toRemove.add(key);
          }
        }
      } catch (_) {
        // Remove corrupted entries
        toRemove.add(key as String);
      }
    }

    for (final key in toRemove) {
      await _box!.delete(key);
    }

    FluQueryLogger.debug('Removed ${toRemove.length} persisted queries');
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    final count = _box!.length;
    await _box!.clear();
    FluQueryLogger.info('Cleared $count persisted queries');
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _isInitialized = false;
      FluQueryLogger.debug('HiveCePersister closed');
    }
  }

  /// Get the number of cached entries
  int get length => _box?.length ?? 0;

  /// Whether the persister is initialized
  bool get isInitialized => _isInitialized;

  /// Compact the Hive box to reduce file size
  Future<void> compact() async {
    _ensureInitialized();
    await _box!.compact();
    FluQueryLogger.debug('HiveCePersister compacted');
  }
}

// Keep the old class name as an alias for backward compatibility
@Deprecated('Use HiveCePersister instead')
typedef HivePersister = HiveCePersister;
