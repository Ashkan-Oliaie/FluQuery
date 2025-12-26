import '../service_ref.dart';

/// Context for tracking service resolution state.
///
/// Provides clean tracking of:
/// - Currently resolving services (for circular dependency detection)
/// - Resolution root (first service in chain, for store ownership)
class ResolutionContext {
  /// Services currently being resolved (for circular detection)
  final Set<Type> _resolving = {};

  /// The root service that started the resolution chain
  Type? _root;

  /// Get the resolution root.
  Type? get root => _root;

  /// Whether we're currently in a resolution.
  bool get isResolving => _resolving.isNotEmpty;

  /// Check if a type is currently being resolved (circular dependency).
  bool isCurrentlyResolving(Type type) => _resolving.contains(type);

  /// Get the current resolution chain (for error messages).
  List<Type> get chain => _resolving.toList();

  /// Enter resolution of a service type.
  /// Returns true if this is the root of the resolution chain.
  bool enter(Type type) {
    if (_resolving.contains(type)) {
      throw CircularDependencyException([..._resolving, type].toList());
    }

    final isRoot = _resolving.isEmpty;
    if (isRoot) {
      _root = type;
    }

    _resolving.add(type);
    return isRoot;
  }

  /// Exit resolution of a service type.
  void exit(Type type, {required bool wasRoot}) {
    _resolving.remove(type);
    if (wasRoot) {
      _root = null;
    }
  }
}
