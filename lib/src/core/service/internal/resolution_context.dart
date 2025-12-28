import '../service_ref.dart';

/// Context for tracking service resolution state.
///
/// Provides circular dependency detection during service resolution.
class ResolutionContext {
  /// Services currently being resolved (for circular detection)
  final Set<Type> _resolving = {};

  /// Whether we're currently in a resolution.
  bool get isResolving => _resolving.isNotEmpty;

  /// Check if a type is currently being resolved (circular dependency).
  bool isCurrentlyResolving(Type type) => _resolving.contains(type);

  /// Get the current resolution chain (for error messages).
  List<Type> get chain => _resolving.toList();

  /// Enter resolution of a service type.
  void enter(Type type) {
    if (_resolving.contains(type)) {
      throw CircularDependencyException([..._resolving, type].toList());
    }
    _resolving.add(type);
  }

  /// Exit resolution of a service type.
  void exit(Type type) {
    _resolving.remove(type);
  }
}
