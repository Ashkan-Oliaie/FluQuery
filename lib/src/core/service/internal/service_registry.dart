import '../service.dart';
import '../../common/common.dart';

/// Internal registry for service registrations.
///
/// Handles storage and retrieval of service factories.
/// Supports singleton, factory, and named registrations.
class ServiceRegistry {
  /// Singleton registrations: Type -> Registration
  final Map<Type, ServiceRegistration> _singletons = {};

  /// Named singleton registrations: Type -> (Name -> Registration)
  final Map<Type, Map<String, ServiceRegistration>> _namedSingletons = {};

  /// Factory registrations: Type -> Registration (new instance each call)
  final Map<Type, ServiceRegistration> _factories = {};

  /// Named factory registrations: Type -> (Name -> Registration)
  final Map<Type, Map<String, ServiceRegistration>> _namedFactories = {};

  /// Parent registry for scoping
  final ServiceRegistry? _parent;

  ServiceRegistry({ServiceRegistry? parent}) : _parent = parent;

  // ============================================================
  // SINGLETON REGISTRATION
  // ============================================================

  /// Register a singleton service.
  void registerSingleton<T extends Service>(
    ServiceFactory<T> factory, {
    bool lazy = true,
  }) {
    if (_singletons.containsKey(T)) {
      FluQueryLogger.warn('Service $T is already registered. Overwriting.');
    }
    _singletons[T] = ServiceRegistration<T>(factory: factory, lazy: lazy);
  }

  /// Register a named singleton service.
  void registerNamedSingleton<T extends Service>(
    String name,
    ServiceFactory<T> factory, {
    bool lazy = true,
  }) {
    _namedSingletons.putIfAbsent(T, () => {})[name] =
        ServiceRegistration<T>(factory: factory, lazy: lazy);
    FluQueryLogger.debug('Registered named service: $T($name)');
  }

  /// Get singleton registration by type.
  ServiceRegistration<T>? getSingletonRegistration<T extends Service>() {
    final reg = _singletons[T] as ServiceRegistration<T>?;
    if (reg != null) return reg;
    return _parent?.getSingletonRegistration<T>();
  }

  /// Get singleton registration by runtime type (for eager init).
  ServiceRegistration? getSingletonRegistrationByType(Type type) {
    final reg = _singletons[type];
    if (reg != null) return reg;
    return _parent?.getSingletonRegistrationByType(type);
  }

  /// Get named singleton registration.
  ServiceRegistration<T>? getNamedSingletonRegistration<T extends Service>(
      String name) {
    final reg = _namedSingletons[T]?[name] as ServiceRegistration<T>?;
    if (reg != null) return reg;
    return _parent?.getNamedSingletonRegistration<T>(name);
  }

  /// Remove singleton registration.
  void unregisterSingleton<T extends Service>() {
    _singletons.remove(T);
  }

  /// Remove named singleton registration.
  void unregisterNamedSingleton<T extends Service>(String name) {
    _namedSingletons[T]?.remove(name);
  }

  // ============================================================
  // FACTORY REGISTRATION
  // ============================================================

  /// Register a factory (new instance each call).
  void registerFactory<T extends Service>(ServiceFactory<T> factory) {
    if (_factories.containsKey(T)) {
      FluQueryLogger.warn('Factory $T is already registered. Overwriting.');
    }
    _factories[T] = ServiceRegistration<T>(factory: factory, lazy: true);
  }

  /// Register a named factory.
  void registerNamedFactory<T extends Service>(
      String name, ServiceFactory<T> factory) {
    _namedFactories.putIfAbsent(T, () => {})[name] =
        ServiceRegistration<T>(factory: factory, lazy: true);
    FluQueryLogger.debug('Registered named factory: $T($name)');
  }

  /// Get factory registration by type.
  ServiceRegistration<T>? getFactoryRegistration<T extends Service>() {
    final reg = _factories[T] as ServiceRegistration<T>?;
    if (reg != null) return reg;
    return _parent?.getFactoryRegistration<T>();
  }

  /// Get named factory registration.
  ServiceRegistration<T>? getNamedFactoryRegistration<T extends Service>(
      String name) {
    final reg = _namedFactories[T]?[name] as ServiceRegistration<T>?;
    if (reg != null) return reg;
    return _parent?.getNamedFactoryRegistration<T>(name);
  }

  // ============================================================
  // QUERIES
  // ============================================================

  /// Check if a service is registered (singleton or factory).
  bool has<T extends Service>() {
    return _singletons.containsKey(T) ||
        _factories.containsKey(T) ||
        (_parent?.has<T>() ?? false);
  }

  /// Check if a named service is registered.
  bool hasNamed<T extends Service>(String name) {
    return _namedSingletons[T]?.containsKey(name) == true ||
        _namedFactories[T]?.containsKey(name) == true ||
        (_parent?.hasNamed<T>(name) ?? false);
  }

  /// Get all eager (non-lazy) singleton registrations.
  Iterable<MapEntry<Type, ServiceRegistration>> get eagerRegistrations =>
      _singletons.entries.where((e) => !e.value.lazy);

  /// Count of registered singletons (for devtools)
  int get singletonCount => _singletons.length + (_parent?.singletonCount ?? 0);

  /// Count of registered factories (for devtools)
  int get factoryCount => _factories.length + (_parent?.factoryCount ?? 0);

  /// Create a child registry for scoping.
  ServiceRegistry createChild() => ServiceRegistry(parent: this);
}
