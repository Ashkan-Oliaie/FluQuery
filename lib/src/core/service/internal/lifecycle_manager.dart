import 'dart:async';
import '../service.dart';
import '../service_key.dart';
import '../../common/common.dart';

/// Async lock that ensures only one initialization runs at a time.
/// Subsequent calls wait for the first to complete.
class AsyncLock {
  Completer<void>? _completer;

  /// Execute [action] with mutual exclusion.
  /// If already running, waits for completion without re-executing.
  Future<void> synchronized(Future<void> Function() action) async {
    if (_completer != null) {
      await _completer!.future;
      return;
    }

    _completer = Completer<void>();

    try {
      await action();
      _completer!.complete();
    } catch (e, st) {
      _completer!.completeError(e, st);
      rethrow;
    } finally {
      _completer = null;
    }
  }

  /// Whether currently executing.
  bool get isRunning => _completer != null;

  /// Wait for current execution to complete (if any).
  Future<void> waitIfRunning() async {
    if (_completer != null) {
      await _completer!.future.catchError((_) {});
    }
  }
}

/// Manages service lifecycle: initialization, disposal, and reset.
///
/// Provides thread-safe initialization with per-service locks to prevent
/// race conditions when multiple callers request the same service.
class LifecycleManager {
  /// Locks for initialization (one per service key)
  final Map<ServiceKey, AsyncLock> _initLocks = {};

  /// Currently initializing service (for store ownership tracking)
  Type? _currentlyInitializing;

  /// Get the currently initializing service type.
  Type? get currentlyInitializing => _currentlyInitializing;

  /// Initialize a service with a lock to prevent double initialization.
  Future<void> initializeWithLock(ServiceKey key, Service service) async {
    if (service.isInitialized) return;

    final lock = _initLocks.putIfAbsent(key, () => AsyncLock());
    await lock.synchronized(() => _doInitialize(service));
  }

  Future<void> _doInitialize(Service service) async {
    if (service.isInitialized) return;

    final previouslyInitializing = _currentlyInitializing;
    _currentlyInitializing = service.runtimeType;

    try {
      await service.initialize();
      FluQueryLogger.debug('Initialized service: ${service.runtimeType}');
    } catch (e, stackTrace) {
      FluQueryLogger.error(
        'Failed to initialize service ${service.runtimeType}: $e',
        e,
        stackTrace,
      );
      rethrow;
    } finally {
      _currentlyInitializing = previouslyInitializing;
    }
  }

  /// Dispose a service.
  Future<void> dispose(Service service) async {
    if (service.isDisposed) return;
    await service.dispose();
    FluQueryLogger.debug('Disposed service: ${service.runtimeType}');
  }

  /// Reset a service.
  Future<void> reset(Service service) async {
    await service.reset();
    FluQueryLogger.debug('Reset service: ${service.runtimeType}');
  }

  /// Wait for all pending initializations to complete.
  Future<void> waitForPendingInitializations() async {
    final runningLocks = _initLocks.values.where((l) => l.isRunning).toList();
    if (runningLocks.isNotEmpty) {
      FluQueryLogger.debug(
          'Waiting for ${runningLocks.length} pending initializations');
      await Future.wait(runningLocks.map((l) => l.waitIfRunning()));
    }
  }

  /// Clear all locks.
  void clear() {
    _initLocks.clear();
  }
}
