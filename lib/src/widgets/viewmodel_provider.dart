import 'package:flutter/material.dart';
import '../core/service/service.dart';
import '../core/service/service_container.dart';
import '../core/service/service_ref.dart';
import 'query_client_provider.dart';

/// Provider for screen-scoped ViewModels (factory services).
///
/// - Registers the ViewModel as a named service (shows in devtools)
/// - Disposes automatically when the widget is removed
/// - Children access via `ViewModelProvider.of<T>(context)`
///
/// ```dart
/// // Wrap your screen
/// ViewModelProvider<ProductViewModel>(
///   name: 'product-123',
///   create: (ref) => ProductViewModel(productId: '123'),
///   child: ProductScreen(),
/// )
///
/// // Access in children
/// final vm = ViewModelProvider.of<ProductViewModel>(context);
/// final price = useValueListenable(vm.price);
/// ```
class ViewModelProvider<T extends Service> extends StatefulWidget {
  /// Unique name for this ViewModel instance (e.g., 'product-123')
  final String name;

  /// Factory to create the ViewModel
  final T Function(ServiceRef ref) create;

  /// Child widget tree
  final Widget child;

  /// Optional loading widget while ViewModel initializes
  final Widget? loading;

  const ViewModelProvider({
    super.key,
    required this.name,
    required this.create,
    required this.child,
    this.loading,
  });

  /// Get ViewModel from context
  static T of<T extends Service>(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_ViewModelScope<T>>();
    if (inherited == null) {
      throw FlutterError(
        'ViewModelProvider.of<$T>() called but no ViewModelProvider<$T> found.\n'
        'Make sure to wrap your widget tree with ViewModelProvider<$T>.',
      );
    }
    return inherited.viewModel;
  }

  /// Try to get ViewModel from context (returns null if not found)
  static T? maybeOf<T extends Service>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ViewModelScope<T>>()
        ?.viewModel;
  }

  @override
  State<ViewModelProvider<T>> createState() => _ViewModelProviderState<T>();
}

class _ViewModelProviderState<T extends Service>
    extends State<ViewModelProvider<T>> {
  T? _viewModel;
  ServiceContainer? _services;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Schedule initialization after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    try {
      final client = QueryClientProvider.of(context);
      _services = client.services;

      if (_services == null) {
        throw StateError(
          'ViewModelProvider requires QueryClient with ServiceContainer.\n'
          'Did you call QueryClient.initServices()?',
        );
      }

      // Register as named service
      _services!.registerNamed<T>(widget.name, widget.create, lazy: false);

      // Get and initialize
      final vm = await _services!.get<T>(name: widget.name);

      if (mounted) {
        setState(() => _viewModel = vm);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  @override
  void dispose() {
    // Unregister and dispose
    _services?.unregister<T>(name: widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          'ViewModelProvider error: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_viewModel == null) {
      return widget.loading ?? const Center(child: CircularProgressIndicator());
    }

    return _ViewModelScope<T>(
      viewModel: _viewModel as T,
      child: widget.child,
    );
  }
}

class _ViewModelScope<T extends Service> extends InheritedWidget {
  final T viewModel;

  const _ViewModelScope({
    required this.viewModel,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ViewModelScope<T> old) => viewModel != old.viewModel;
}
