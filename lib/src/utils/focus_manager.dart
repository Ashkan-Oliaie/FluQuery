import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/query_client.dart';
import '../core/logger.dart';

import 'focus_manager_web.dart' if (dart.library.io) 'focus_manager_io.dart'
    as platform;

/// Manages app lifecycle and focus state for automatic refetching
class QueryFocusManager with WidgetsBindingObserver {
  final QueryClient _client;
  bool _isInitialized = false;
  Object? _webListener;

  QueryFocusManager(this._client);

  /// Initialize the focus manager
  void init() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // On web, also listen to visibility change events
    if (kIsWeb) {
      _webListener = platform.initWebFocusListener(
        onFocus: () {
          FluQueryLogger.debug('Web window focused');
          _client.setFocused(true);
        },
        onBlur: () {
          FluQueryLogger.debug('Web window blurred');
          _client.setFocused(false);
        },
      );
    }
  }

  /// Dispose the focus manager
  void dispose() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);

    if (kIsWeb && _webListener != null) {
      platform.disposeWebFocusListener(_webListener!);
    }

    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This works on mobile platforms (Android/iOS)
    switch (state) {
      case AppLifecycleState.resumed:
        FluQueryLogger.debug('App lifecycle: resumed');
        _client.setFocused(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        FluQueryLogger.debug('App lifecycle: ${state.name}');
        _client.setFocused(false);
        break;
    }
  }
}
