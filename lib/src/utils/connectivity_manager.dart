import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/query_client.dart';
import '../core/logger.dart';

/// Manages network connectivity state for automatic refetching
class ConnectivityManager {
  final QueryClient _client;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;

  ConnectivityManager(this._client);

  /// Initialize the connectivity manager
  Future<void> init() async {
    if (_isInitialized) return;

    // Check initial connectivity
    final results = await Connectivity().checkConnectivity();
    _updateConnectivity(results);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectivity);
    _isInitialized = true;

    FluQueryLogger.debug('ConnectivityManager initialized');
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.isNotEmpty && 
        !results.every((r) => r == ConnectivityResult.none);
    _client.setOnline(isOnline);
    FluQueryLogger.debug('Connectivity changed: online=$isOnline');
  }

  /// Dispose the connectivity manager
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }
}

