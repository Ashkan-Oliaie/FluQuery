import 'package:flutter_test/flutter_test.dart';
import 'package:fluquery/fluquery.dart';

// ============================================================
// TEST SERVICES
// ============================================================

class LoggingService extends Service {
  final List<String> logs = [];
  bool initCalled = false;
  bool disposeCalled = false;
  bool resetCalled = false;

  void log(String message) {
    logs.add(message);
  }

  @override
  Future<void> onInit() async {
    initCalled = true;
    logs.add('LoggingService initialized');
  }

  @override
  Future<void> onDispose() async {
    disposeCalled = true;
    logs.add('LoggingService disposed');
  }

  @override
  Future<void> onReset() async {
    resetCalled = true;
    logs.clear();
  }
}

class ApiClient extends Service {
  final LoggingService logger;
  bool initCalled = false;

  ApiClient(ServiceRef ref) : logger = ref.getSync<LoggingService>();

  Future<String> fetchData() async {
    logger.log('ApiClient fetching data');
    return 'data from api';
  }

  @override
  Future<void> onInit() async {
    initCalled = true;
    logger.log('ApiClient initialized');
  }
}

class AuthService extends Service {
  final ApiClient api;
  final LoggingService logger;
  late final QueryStore<String?, Object> userStore;
  bool initCalled = false;

  AuthService(ServiceRef ref)
      : api = ref.getSync<ApiClient>(),
        logger = ref.getSync<LoggingService>() {
    userStore = ref.createStore<String?, Object>(
      queryKey: ['auth', 'user'],
      queryFn: (_) async => 'test-user',
    );
  }

  String? get currentUser => userStore.data;

  Future<void> login() async {
    logger.log('AuthService login');
    await userStore.refetch();
  }

  @override
  Future<void> onInit() async {
    initCalled = true;
    logger.log('AuthService initialized');
  }
}

class CircularServiceA extends Service {
  late final CircularServiceB b;

  CircularServiceA(ServiceRef ref) {
    b = ref.getSync<CircularServiceB>();
  }
}

class CircularServiceB extends Service {
  late final CircularServiceA a;

  CircularServiceB(ServiceRef ref) {
    a = ref.getSync<CircularServiceA>();
  }
}

class EagerService extends Service {
  static int instanceCount = 0;
  final int instanceId;

  EagerService(ServiceRef ref) : instanceId = ++instanceCount;
}

class AsyncInitService extends Service {
  bool initComplete = false;
  int initCallCount = 0;

  @override
  Future<void> onInit() async {
    initCallCount++;
    await Future.delayed(const Duration(milliseconds: 100));
    initComplete = true;
  }
}

// ============================================================
// TESTS
// ============================================================

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
    EagerService.instanceCount = 0;
  });

  tearDown(() async {
    await client.dispose();
  });

  group('ServiceContainer', () {
    group('Registration', () {
      test('registers and retrieves a service', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        expect(logger, isA<LoggingService>());
      });

      test('throws ServiceNotFoundException for unregistered service',
          () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        expect(
          () => client.getService<ApiClient>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });

      test('overwrites existing registration with warning', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<LoggingService>((ref) => LoggingService());
        });

        // Should not throw - just warns
        final logger = client.getService<LoggingService>();
        expect(logger, isNotNull);
      });
    });

    group('Dependency Resolution', () {
      test('resolves service dependencies', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
        });

        final api = client.getService<ApiClient>();
        expect(api.logger, isA<LoggingService>());
      });

      test('resolves deep dependency chains', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
          container.register<AuthService>((ref) => AuthService(ref));
        });

        final auth = client.getService<AuthService>();
        expect(auth.api, isA<ApiClient>());
        expect(auth.logger, isA<LoggingService>());
        expect(auth.api.logger, same(auth.logger));
      });

      test('detects circular dependencies', () async {
        await client.initServices((container) {
          container.register<CircularServiceA>((ref) => CircularServiceA(ref));
          container.register<CircularServiceB>((ref) => CircularServiceB(ref));
        });

        expect(
          () => client.getService<CircularServiceA>(),
          throwsA(isA<CircularDependencyException>()),
        );
      });

      test('shares single instance across consumers', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
          container.register<AuthService>((ref) => AuthService(ref));
        });

        final logger1 = client.getService<LoggingService>();
        final logger2 = client.getService<LoggingService>();
        final auth = client.getService<AuthService>();

        expect(logger1, same(logger2));
        expect(auth.logger, same(logger1));
      });
    });

    group('Lazy Initialization', () {
      test('lazy services are not instantiated until accessed', () async {
        await client.initServices((container) {
          container.register<EagerService>((ref) => EagerService(ref));
        });

        expect(EagerService.instanceCount, 0);

        client.getService<EagerService>();
        expect(EagerService.instanceCount, 1);
      });

      test('eager services are instantiated during initialize()', () async {
        await client.initServices((container) {
          container.register<EagerService>(
            (ref) => EagerService(ref),
            lazy: false,
          );
        });

        expect(EagerService.instanceCount, 1);
      });
    });

    group('Lifecycle', () {
      test('onInit is called during initialization', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        expect(logger.initCalled, true);
      });

      test('onInit is called in dependency order', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
        });

        // Access ApiClient which depends on LoggingService
        final api = client.getService<ApiClient>();

        // Check that LoggingService was initialized first
        expect(api.logger.logs, contains('LoggingService initialized'));
        expect(api.logger.logs, contains('ApiClient initialized'));
        expect(
          api.logger.logs.indexOf('LoggingService initialized'),
          lessThan(api.logger.logs.indexOf('ApiClient initialized')),
        );
      });

      test('async onInit completes before service is ready', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>(
            (ref) => AsyncInitService(),
            lazy: false,
          );
        });

        final service = client.getService<AsyncInitService>();
        expect(service.initComplete, true);
      });

      test(
          'getAsync prevents race condition - parallel calls share single init',
          () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((ref) => AsyncInitService());
        });

        // Simulate multiple widgets requesting the same service simultaneously
        final futures =
            List.generate(10, (_) => client.services!.get<AsyncInitService>());
        final results = await Future.wait(futures);

        // All should return the same instance
        for (final service in results) {
          expect(service, same(results.first));
        }

        // onInit should only be called ONCE (race condition fixed!)
        expect(results.first.initCallCount, 1);
        expect(results.first.initComplete, true);
      });

      test('onDispose is called when service is disposed', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        await client.services!.dispose<LoggingService>();

        expect(logger.disposeCalled, true);
      });

      test('disposeAll disposes all services', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
        });

        final logger = client.getService<LoggingService>();
        client.getService<ApiClient>();

        await client.services!.disposeAll();

        expect(logger.disposeCalled, true);
      });

      test('onReset is called when service is reset', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        logger.log('test message');
        expect(logger.logs.length, 2); // init + test message

        await client.resetService<LoggingService>();

        expect(logger.resetCalled, true);
        expect(logger.logs, isEmpty);
      });

      test('resetAll resets all services', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        await client.resetAllServices();

        expect(logger.resetCalled, true);
      });
    });

    group('QueryStore Integration', () {
      test('services can create QueryStores', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
          container.register<AuthService>((ref) => AuthService(ref));
        });

        final auth = client.getService<AuthService>();
        expect(auth.userStore, isA<QueryStore<String?, Object>>());
      });

      test('service stores are functional', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
          container.register<AuthService>((ref) => AuthService(ref));
        });

        final auth = client.getService<AuthService>();

        // Initially null
        expect(auth.currentUser, isNull);

        // After login (triggers refetch)
        await auth.login();

        // Wait for the store to update
        await Future.delayed(const Duration(milliseconds: 50));

        expect(auth.currentUser, 'test-user');
      });
    });

    group('Scoping', () {
      test('child scope inherits parent registrations', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final childScope = client.services!.createScope();

        final logger = childScope.getSync<LoggingService>();
        expect(logger, isA<LoggingService>());
      });

      test('child scope can override parent registrations', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final parentLogger = client.getService<LoggingService>();

        final childScope = client.services!.createScope();
        childScope.register<LoggingService>((ref) => LoggingService());

        final childLogger = childScope.get<LoggingService>();

        expect(childLogger, isNot(same(parentLogger)));
      });
    });

    group('Error Handling', () {
      test('disposed service can be recreated', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final logger1 = client.getService<LoggingService>();
        expect(logger1.initCalled, true);

        await client.services!.dispose<LoggingService>();
        expect(logger1.disposeCalled, true);

        // After dispose, getting the service creates a new instance
        final logger2 = client.getService<LoggingService>();
        expect(logger2, isNot(same(logger1)));
        expect(logger2.initCalled, true);
      });

      test('getService throws if services not initialized', () {
        expect(
          () => client.getService<LoggingService>(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });

  group('QueryClient Service Integration', () {
    test('initServices creates and initializes container', () async {
      expect(client.services, isNull);

      await client.initServices((container) {
        container.register<LoggingService>((ref) => LoggingService());
      });

      expect(client.services, isNotNull);
      expect(client.services!.isInitialized, true);
    });

    test('dispose() disposes services', () async {
      await client.initServices((container) {
        container.register<LoggingService>((ref) => LoggingService());
      });

      final logger = client.getService<LoggingService>();
      await client.dispose();

      expect(logger.disposeCalled, true);
    });
  });

  // ============================================================
  // EDGE CASE TESTS
  // ============================================================

  group('Edge Cases', () {
    group('Concurrent Access', () {
      test('100 parallel getAsync calls only initialize once', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((ref) => AsyncInitService());
        });

        // Fire 100 parallel requests
        final futures = List.generate(
          100,
          (_) => client.services!.get<AsyncInitService>(),
        );
        final results = await Future.wait(futures);

        // All should be same instance
        for (final service in results) {
          expect(service, same(results.first));
        }

        // Init should only be called ONCE
        expect(results.first.initCallCount, 1);
      });

      test('getAsync during dispose waits properly', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((ref) => AsyncInitService());
        });

        // Start getting service (will trigger init)
        final getFuture = client.services!.get<AsyncInitService>();

        // Immediately try to dispose
        final disposeFuture = client.services!.disposeAll();

        // Both should complete without error
        await Future.wait([getFuture, disposeFuture]);
      });

      test('init failure propagates to all waiting callers', () async {
        var callCount = 0;

        await client.initServices((container) {
          container
              .register<FailingInitService>((ref) => FailingInitService(() {
                    callCount++;
                  }));
        });

        // Multiple parallel calls
        final futures = List.generate(
          5,
          (_) => client.services!.get<FailingInitService>(),
        );

        // All should fail with same error
        for (final future in futures) {
          await expectLater(future, throwsA(isA<Exception>()));
        }

        // Init should only be attempted once
        expect(callCount, 1);
      });
    });

    group('Store Ownership', () {
      test('store created in constructor is owned by root service', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
          container.register<AuthService>((ref) => AuthService(ref));
        });

        final auth = client.getService<AuthService>();
        expect(auth.userStore, isNotNull);

        // Disposing AuthService should dispose its store
        await client.services!.dispose<AuthService>();
        expect(auth.userStore.isDisposed, true);
      });

      test('store created in onInit is owned by initializing service',
          () async {
        await client.initServices((container) {
          container.register<StoreInOnInitService>(
              (ref) => StoreInOnInitService(ref));
        });

        final service = client.getService<StoreInOnInitService>();
        expect(service.lateStore, isNotNull);

        // Dispose should clean up the store
        await client.services!.dispose<StoreInOnInitService>();
        expect(service.lateStore!.isDisposed, true);
      });
    });

    group('Lifecycle Edge Cases', () {
      test('reset during active init waits for init to complete', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((ref) => AsyncInitService());
        });

        // Start getting service with getAsync to ensure init starts
        final serviceFuture = client.services!.get<AsyncInitService>();

        // Reset while init is running (don't await getAsync yet)
        final resetFuture = client.resetService<AsyncInitService>();

        // Wait for both
        final service = await serviceFuture;
        await resetFuture;

        // Service should be initialized (reset happened after init completed)
        expect(service.isInitialized, true);
      });

      test('double initialize is idempotent', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final container = client.services!;

        // Second initialize should be a no-op
        await container.initialize();
        await container.initialize();

        expect(container.isInitialized, true);
      });

      test('dispose then get recreates service', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final first = client.getService<LoggingService>();
        await client.services!.dispose<LoggingService>();

        final second = client.getService<LoggingService>();

        expect(second, isNot(same(first)));
        expect(second.isDisposed, false);
      });

      test('unregister removes registration and instance', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
        });

        final service = client.getService<LoggingService>();
        await client.services!.unregister<LoggingService>();

        expect(service.disposeCalled, true);
        expect(client.services!.has<LoggingService>(), false);
        expect(
          () => client.getService<LoggingService>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });
    });

    group('Dependency Chain Edge Cases', () {
      test('deep dependency chain (5 levels) resolves correctly', () async {
        await client.initServices((container) {
          container.register<Level5Service>((ref) => Level5Service());
          container.register<Level4Service>((ref) => Level4Service(ref));
          container.register<Level3Service>((ref) => Level3Service(ref));
          container.register<Level2Service>((ref) => Level2Service(ref));
          container.register<Level1Service>((ref) => Level1Service(ref));
        });

        final level1 = client.getService<Level1Service>();
        expect(level1.level2.level3.level4.level5, isA<Level5Service>());
      });

      test('diamond dependency resolves to single instance', () async {
        // A depends on B and C, both depend on D
        await client.initServices((container) {
          container.register<DiamondD>((ref) => DiamondD());
          container.register<DiamondB>((ref) => DiamondB(ref));
          container.register<DiamondC>((ref) => DiamondC(ref));
          container.register<DiamondA>((ref) => DiamondA(ref));
        });

        final a = client.getService<DiamondA>();

        // Both B and C should share the same D
        expect(a.b.d, same(a.c.d));
      });
    });

    group('Memory Safety', () {
      test('disposed container clears all references', () async {
        await client.initServices((container) {
          container.register<LoggingService>((ref) => LoggingService());
          container.register<ApiClient>((ref) => ApiClient(ref));
        });

        client.getService<LoggingService>();
        client.getService<ApiClient>();

        await client.services!.disposeAll();

        expect(client.services!.isInstantiated<LoggingService>(), false);
        expect(client.services!.isInstantiated<ApiClient>(), false);
      });
    });
  });

  // ============================================================
  // FACTORY REGISTRATION TESTS
  // ============================================================

  group('Factory Registration', () {
    setUp(() {
      RequestService.resetCounter();
      FormValidator.resetCounter();
    });

    test('registerFactory creates new instance on every create() call',
        () async {
      await client.initServices((container) {
        container.registerFactory<RequestService>((ref) => RequestService());
      });

      final req1 = client.services!.create<RequestService>();
      final req2 = client.services!.create<RequestService>();
      final req3 = client.services!.create<RequestService>();

      // Each should be a different instance
      expect(req1, isNot(same(req2)));
      expect(req2, isNot(same(req3)));

      // Each should have unique instance ID
      expect(req1.instanceId, 1);
      expect(req2.instanceId, 2);
      expect(req3.instanceId, 3);
    });

    test('factory instances are not cached', () async {
      await client.initServices((container) {
        container.registerFactory<RequestService>((ref) => RequestService());
      });

      // Create 100 instances
      final instances = List.generate(
        100,
        (_) => client.services!.create<RequestService>(),
      );

      // All should be unique
      final uniqueIds = instances.map((i) => i.instanceId).toSet();
      expect(uniqueIds.length, 100);
    });

    test('factory can receive parameters via closure', () async {
      await client.initServices((container) {
        // Using closure to pass parameters
        container.registerFactory<FormValidator>(
          (ref) => FormValidator('form-${FormValidator.instanceCounter + 1}'),
        );
      });

      final v1 = client.services!.create<FormValidator>();
      final v2 = client.services!.create<FormValidator>();

      expect(v1.formId, 'form-1');
      expect(v2.formId, 'form-2');
    });

    test('factory throws ServiceNotFoundException if not registered', () async {
      await client.initServices((container) {
        // Don't register anything
      });

      expect(
        () => client.services!.create<RequestService>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('factory can depend on singletons', () async {
      await client.initServices((container) {
        container.register<LoggingService>((ref) => LoggingService());
        container.registerFactory<ApiRequestService>(
            (ref) => ApiRequestService(ref));
      });

      final req1 = client.services!.create<ApiRequestService>();
      final req2 = client.services!.create<ApiRequestService>();

      // Different request instances
      expect(req1, isNot(same(req2)));

      // But same shared logger
      expect(req1.logger, same(req2.logger));
    });

    test('factory instances are NOT auto-disposed', () async {
      await client.initServices((container) {
        container.registerFactory<RequestService>((ref) => RequestService());
      });

      final req = client.services!.create<RequestService>();

      await client.services!.disposeAll();

      // Factory instance should NOT be disposed (caller's responsibility)
      expect(req.isDisposed, false);
    });

    test('factory vs singleton comparison', () async {
      await client.initServices((container) {
        // Singleton
        container.register<LoggingService>((ref) => LoggingService());
        // Factory
        container.registerFactory<RequestService>((ref) => RequestService());
      });

      // Singleton: same instance
      final log1 = client.getService<LoggingService>();
      final log2 = client.getService<LoggingService>();
      expect(log1, same(log2));

      // Factory: different instances
      final req1 = client.services!.create<RequestService>();
      final req2 = client.services!.create<RequestService>();
      expect(req1, isNot(same(req2)));
    });
  });

  // ============================================================
  // NAMED REGISTRATION TESTS
  // ============================================================

  group('Named Registration', () {
    test('registerNamed allows multiple instances of same type', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
        container.registerNamed<TenantApiClient>(
          'globex',
          (ref) =>
              TenantApiClient(tenantId: 'globex', baseUrl: 'api.globex.com'),
        );
      });

      final acme = client.services!.getSync<TenantApiClient>(name: 'acme');
      final globex = client.services!.getSync<TenantApiClient>(name: 'globex');

      expect(acme.tenantId, 'acme');
      expect(globex.tenantId, 'globex');
      expect(acme, isNot(same(globex)));
    });

    test('named services are cached (singletons per name)', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
      });

      final acme1 = client.services!.getSync<TenantApiClient>(name: 'acme');
      final acme2 = client.services!.getSync<TenantApiClient>(name: 'acme');

      expect(acme1, same(acme2));
    });

    test('named service throws if name not registered', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
      });

      expect(
        () => client.services!.getSync<TenantApiClient>(name: 'nonexistent'),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('named services can coexist with unnamed singleton', () async {
      await client.initServices((container) {
        // Unnamed (default) singleton
        container.register<TenantApiClient>(
          (ref) =>
              TenantApiClient(tenantId: 'default', baseUrl: 'api.default.com'),
        );
        // Named instances
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
      });

      final defaultClient = client.services!.getSync<TenantApiClient>();
      final acmeClient =
          client.services!.getSync<TenantApiClient>(name: 'acme');

      expect(defaultClient.tenantId, 'default');
      expect(acmeClient.tenantId, 'acme');
      expect(defaultClient, isNot(same(acmeClient)));
    });

    test('named services are disposed with disposeAll', () async {
      await client.initServices((container) {
        container.registerNamed<LoggingService>(
          'audit',
          (ref) => LoggingService(),
        );
        container.registerNamed<LoggingService>(
          'debug',
          (ref) => LoggingService(),
        );
      });

      final audit = client.services!.getSync<LoggingService>(name: 'audit');
      final debug = client.services!.getSync<LoggingService>(name: 'debug');

      await client.services!.disposeAll();

      expect(audit.disposeCalled, true);
      expect(debug.disposeCalled, true);
    });

    test('unregister removes specific named service', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
        container.registerNamed<TenantApiClient>(
          'globex',
          (ref) =>
              TenantApiClient(tenantId: 'globex', baseUrl: 'api.globex.com'),
        );
      });

      // Get both
      client.services!.getSync<TenantApiClient>(name: 'acme');
      client.services!.getSync<TenantApiClient>(name: 'globex');

      // Unregister only acme
      await client.services!.unregister<TenantApiClient>(name: 'acme');

      // acme should be gone
      expect(
        () => client.services!.getSync<TenantApiClient>(name: 'acme'),
        throwsA(isA<ServiceNotFoundException>()),
      );

      // globex should still work
      final globex = client.services!.getSync<TenantApiClient>(name: 'globex');
      expect(globex.tenantId, 'globex');
    });

    test('child scope inherits named registrations from parent', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
      });

      final childScope = client.services!.createScope();

      final acme = childScope.getSync<TenantApiClient>(name: 'acme');
      expect(acme.tenantId, 'acme');
    });

    test('child scope can override parent named registration', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (ref) =>
              TenantApiClient(tenantId: 'acme-parent', baseUrl: 'parent.com'),
        );
      });

      final parentAcme =
          client.services!.getSync<TenantApiClient>(name: 'acme');

      final childScope = client.services!.createScope();
      childScope.registerNamed<TenantApiClient>(
        'acme',
        (ref) => TenantApiClient(tenantId: 'acme-child', baseUrl: 'child.com'),
      );
      await childScope.initialize();

      final childAcme = childScope.getSync<TenantApiClient>(name: 'acme');

      expect(parentAcme.tenantId, 'acme-parent');
      expect(childAcme.tenantId, 'acme-child');
    });
  });

  // ============================================================
  // NAMED FACTORY TESTS
  // ============================================================

  group('Named Factory Registration', () {
    setUp(() {
      FormValidator.resetCounter();
    });

    test('registerFactory with name creates named factories', () async {
      await client.initServices((container) {
        container.registerFactory<FormValidator>(
          (ref) => FormValidator('login'),
          name: 'login',
        );
        container.registerFactory<FormValidator>(
          (ref) => FormValidator('signup'),
          name: 'signup',
        );
      });

      final login1 = client.services!.create<FormValidator>(name: 'login');
      final login2 = client.services!.create<FormValidator>(name: 'login');
      final signup = client.services!.create<FormValidator>(name: 'signup');

      // Each create is unique
      expect(login1, isNot(same(login2)));

      // Different names produce different formIds
      expect(login1.formId, 'login');
      expect(signup.formId, 'signup');
    });

    test('named factory throws if name not registered', () async {
      await client.initServices((container) {
        container.registerFactory<FormValidator>(
          (ref) => FormValidator('default'),
          name: 'login',
        );
      });

      expect(
        () => client.services!.create<FormValidator>(name: 'nonexistent'),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });
  });
}

// ============================================================
// ADDITIONAL FACTORY TEST SERVICE
// ============================================================

class ApiRequestService extends Service {
  final LoggingService logger;
  static int requestCounter = 0;
  final int requestId;

  ApiRequestService(ServiceRef ref)
      : logger = ref.getSync<LoggingService>(),
        requestId = ++requestCounter;
}

// ============================================================
// ADDITIONAL TEST SERVICES
// ============================================================

class FailingInitService extends Service {
  final void Function() onInitAttempt;

  FailingInitService(this.onInitAttempt);

  @override
  Future<void> onInit() async {
    onInitAttempt();
    await Future.delayed(const Duration(milliseconds: 50));
    throw Exception('Init failed intentionally');
  }
}

class StoreInOnInitService extends Service {
  final ServiceRef _ref;
  QueryStore<String?, Object>? lateStore;

  StoreInOnInitService(this._ref);

  @override
  Future<void> onInit() async {
    lateStore = _ref.createStore<String?, Object>(
      queryKey: ['late', 'store'],
      queryFn: (_) async => 'late-data',
    );
  }
}

// Deep dependency chain services
class Level5Service extends Service {}

class Level4Service extends Service {
  final Level5Service level5;
  Level4Service(ServiceRef ref) : level5 = ref.getSync<Level5Service>();
}

class Level3Service extends Service {
  final Level4Service level4;
  Level3Service(ServiceRef ref) : level4 = ref.getSync<Level4Service>();
}

class Level2Service extends Service {
  final Level3Service level3;
  Level2Service(ServiceRef ref) : level3 = ref.getSync<Level3Service>();
}

class Level1Service extends Service {
  final Level2Service level2;
  Level1Service(ServiceRef ref) : level2 = ref.getSync<Level2Service>();
}

// Diamond dependency services
class DiamondD extends Service {}

class DiamondB extends Service {
  final DiamondD d;
  DiamondB(ServiceRef ref) : d = ref.getSync<DiamondD>();
}

class DiamondC extends Service {
  final DiamondD d;
  DiamondC(ServiceRef ref) : d = ref.getSync<DiamondD>();
}

class DiamondA extends Service {
  final DiamondB b;
  final DiamondC c;
  DiamondA(ServiceRef ref)
      : b = ref.getSync<DiamondB>(),
        c = ref.getSync<DiamondC>();
}

// Factory test services
class RequestService extends Service {
  static int instanceCounter = 0;
  final int instanceId;
  final DateTime createdAt;

  RequestService()
      : instanceId = ++instanceCounter,
        createdAt = DateTime.now();

  static void resetCounter() => instanceCounter = 0;
}

class FormValidator extends Service {
  static int instanceCounter = 0;
  final int instanceId;
  final String formId;

  FormValidator(this.formId) : instanceId = ++instanceCounter;

  static void resetCounter() => instanceCounter = 0;

  bool validate(String input) => input.isNotEmpty;
}

// Named service test
class TenantApiClient extends Service {
  final String tenantId;
  final String baseUrl;

  TenantApiClient({required this.tenantId, required this.baseUrl});

  Future<String> fetchData() async {
    return 'Data from $tenantId';
  }
}
