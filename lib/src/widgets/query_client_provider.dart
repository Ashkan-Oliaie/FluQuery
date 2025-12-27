import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/query_client.dart';
import '../utils/focus_manager.dart' show QueryFocusManager;
import '../utils/connectivity_manager.dart';
import '../devtools/devtools.dart';

/// Provides a QueryClient to the widget tree
class QueryClientProvider extends StatefulWidget {
  /// The QueryClient to provide
  final QueryClient client;

  /// Child widget
  final Widget child;

  /// Whether to automatically manage focus refetching
  final bool manageFocus;

  /// Whether to automatically manage connectivity refetching
  final bool manageConnectivity;

  /// Whether to show devtools overlay.
  ///
  /// Defaults to [QueryClientConfig.enableDevtools] if not specified.
  /// Set to `false` to explicitly disable even in debug mode.
  final bool? showDevtools;

  const QueryClientProvider({
    super.key,
    required this.client,
    required this.child,
    this.manageFocus = true,
    this.manageConnectivity = true,
    this.showDevtools,
  });

  /// Get the QueryClient from the context
  static QueryClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_QueryClientInherited>();
    if (provider == null) {
      throw FlutterError(
        'QueryClientProvider.of() called with a context that does not contain a QueryClientProvider.\n'
        'No QueryClientProvider ancestor could be found starting from the context that was passed to QueryClientProvider.of().\n'
        'The context used was: $context',
      );
    }
    return provider.client;
  }

  /// Try to get the QueryClient from the context
  static QueryClient? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_QueryClientInherited>();
    return provider?.client;
  }

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  QueryFocusManager? _focusManager;
  ConnectivityManager? _connectivityManager;

  @override
  void initState() {
    super.initState();
    widget.client.mount();

    if (widget.manageFocus) {
      _focusManager = QueryFocusManager(widget.client);
      _focusManager!.init();
    }

    if (widget.manageConnectivity) {
      _connectivityManager = ConnectivityManager(widget.client);
      _connectivityManager!.init();
    }
  }

  @override
  void dispose() {
    _focusManager?.dispose();
    _connectivityManager?.dispose();
    widget.client.unmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _QueryClientInherited(
      client: widget.client,
      child: widget.child,
    );

    // Only include devtools in debug mode - this allows tree-shaking in release
    // The kDebugMode check is a compile-time constant, so in release builds,
    // this entire block will be removed by the compiler.
    if (kDebugMode) {
      final showDevtools =
          widget.showDevtools ?? widget.client.config.enableDevtools;
      if (showDevtools) {
        child = FluQueryDevtools(
          client: widget.client,
          child: child,
        );
      }
    }

    return child;
  }
}

class _QueryClientInherited extends InheritedWidget {
  final QueryClient client;

  const _QueryClientInherited({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_QueryClientInherited oldWidget) {
    return client != oldWidget.client;
  }
}
