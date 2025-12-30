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
  late final LoggingService logger;
  bool initCalled = false;

  @override
  Future<void> onInit() async {
    logger = ref.getSync<LoggingService>();
    initCalled = true;
    logger.log('ApiClient initialized');
  }

  Future<String> fetchData() async {
    logger.log('ApiClient fetching data');
    return 'data from api';
  }
}

class AuthService extends Service {
  late final ApiClient api;
  late final LoggingService logger;
  bool initCalled = false;
  String? currentUser;

  @override
  Future<void> onInit() async {
    api = ref.getSync<ApiClient>();
    logger = ref.getSync<LoggingService>();
    initCalled = true;
    logger.log('AuthService initialized');
  }

  Future<void> login() async {
    logger.log('AuthService login');
    currentUser = 'test-user';
  }
}

class CircularServiceA extends Service {
  late final CircularServiceB b;

  @override
  Future<void> onInit() async {
    b = ref.getSync<CircularServiceB>();
  }
}

class CircularServiceB extends Service {
  late final CircularServiceA a;

  @override
  Future<void> onInit() async {
    a = ref.getSync<CircularServiceA>();
  }
}

// For constructor-based circular dependency test
class CircularCtorA extends Service {
  CircularCtorA(ServiceRef ref) {
    ref.getSync<CircularCtorB>();
  }
}

class CircularCtorB extends Service {
  CircularCtorB(ServiceRef ref) {
    ref.getSync<CircularCtorA>();
  }
}

class EagerService extends Service {
  static int instanceCount = 0;
  final int instanceId;

  EagerService() : instanceId = ++instanceCount;
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
          container.register<LoggingService>((_) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        expect(logger, isA<LoggingService>());
      });

      test('throws ServiceNotFoundException for unregistered service',
          () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        expect(
          () => client.getService<ApiClient>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });

      test('overwrites existing registration with warning', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<LoggingService>((_) => LoggingService());
        });

        // Should not throw - just warns
        final logger = client.getService<LoggingService>();
        expect(logger, isNotNull);
      });
    });

    group('Dependency Resolution', () {
      test('resolves service dependencies via ref', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
        });

        final api = client.getService<ApiClient>();
        expect(api.logger, isA<LoggingService>());
      });

      test('resolves deep dependency chains', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
          container.register<AuthService>((_) => AuthService());
        });

        final auth = client.getService<AuthService>();
        expect(auth.api, isA<ApiClient>());
        expect(auth.logger, isA<LoggingService>());
        expect(auth.api.logger, same(auth.logger));
      });

      test('detects circular dependencies in constructor', () async {
        await client.initServices((container) {
          container.register<CircularCtorA>((ref) => CircularCtorA(ref));
          container.register<CircularCtorB>((ref) => CircularCtorB(ref));
        });

        expect(
          () => client.getService<CircularCtorA>(),
          throwsA(isA<CircularDependencyException>()),
        );
      });

      test('shares single instance across consumers', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
          container.register<AuthService>((_) => AuthService());
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
          container.register<EagerService>((_) => EagerService());
        });

        expect(EagerService.instanceCount, 0);

        client.getService<EagerService>();
        expect(EagerService.instanceCount, 1);
      });

      test('eager services are instantiated during initialize()', () async {
        await client.initServices((container) {
          container.register<EagerService>(
            (_) => EagerService(),
            lazy: false,
          );
        });

        expect(EagerService.instanceCount, 1);
      });
    });

    group('Lifecycle', () {
      test('onInit is called during initialization', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        expect(logger.initCalled, true);
      });

      test('onInit is called in dependency order', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
        });

        final api = client.getService<ApiClient>();

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
            (_) => AsyncInitService(),
            lazy: false,
          );
        });

        final service = client.getService<AsyncInitService>();
        expect(service.initComplete, true);
      });

      test('getAsync prevents race condition - parallel calls share single init',
          () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((_) => AsyncInitService());
        });

        final futures =
            List.generate(10, (_) => client.services!.get<AsyncInitService>());
        final results = await Future.wait(futures);

        for (final service in results) {
          expect(service, same(results.first));
        }

        expect(results.first.initCallCount, 1);
        expect(results.first.initComplete, true);
      });

      test('onDispose is called when service is disposed', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        await client.services!.dispose<LoggingService>();

        expect(logger.disposeCalled, true);
      });

      test('disposeAll disposes all services', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
        });

        final logger = client.getService<LoggingService>();
        client.getService<ApiClient>();

        await client.services!.disposeAll();

        expect(logger.disposeCalled, true);
      });

      test('onReset is called when service is reset', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
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
          container.register<LoggingService>((_) => LoggingService());
        });

        final logger = client.getService<LoggingService>();
        await client.resetAllServices();

        expect(logger.resetCalled, true);
      });
    });

    group('Scoping', () {
      test('child scope inherits parent registrations', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final childScope = client.services!.createScope();

        final logger = childScope.getSync<LoggingService>();
        expect(logger, isA<LoggingService>());
      });

      test('child scope can override parent registrations', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final parentLogger = client.getService<LoggingService>();

        final childScope = client.services!.createScope();
        childScope.register<LoggingService>((_) => LoggingService());

        final childLogger = childScope.get<LoggingService>();

        expect(childLogger, isNot(same(parentLogger)));
      });
    });

    group('Error Handling', () {
      test('disposed service can be recreated', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final logger1 = client.getService<LoggingService>();
        expect(logger1.initCalled, true);

        await client.services!.dispose<LoggingService>();
        expect(logger1.disposeCalled, true);

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
        container.register<LoggingService>((_) => LoggingService());
      });

      expect(client.services, isNotNull);
      expect(client.services!.isInitialized, true);
    });

    test('dispose() disposes services', () async {
      await client.initServices((container) {
        container.register<LoggingService>((_) => LoggingService());
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
          container.register<AsyncInitService>((_) => AsyncInitService());
        });

        final futures = List.generate(
          100,
          (_) => client.services!.get<AsyncInitService>(),
        );
        final results = await Future.wait(futures);

        for (final service in results) {
          expect(service, same(results.first));
        }

        expect(results.first.initCallCount, 1);
      });

      test('getAsync during dispose waits properly', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((_) => AsyncInitService());
        });

        final getFuture = client.services!.get<AsyncInitService>();
        final disposeFuture = client.services!.disposeAll();

        await Future.wait([getFuture, disposeFuture]);
      });

      test('init failure propagates to all waiting callers', () async {
        var callCount = 0;

        await client.initServices((container) {
          container.register<FailingInitService>((_) => FailingInitService(() {
                callCount++;
              }));
        });

        final futures = List.generate(
          5,
          (_) => client.services!.get<FailingInitService>(),
        );

        for (final future in futures) {
          await expectLater(future, throwsA(isA<Exception>()));
        }

        expect(callCount, 1);
      });
    });

    group('Lifecycle Edge Cases', () {
      test('reset during active init waits for init to complete', () async {
        await client.initServices((container) {
          container.register<AsyncInitService>((_) => AsyncInitService());
        });

        final serviceFuture = client.services!.get<AsyncInitService>();
        final resetFuture = client.resetService<AsyncInitService>();

        final service = await serviceFuture;
        await resetFuture;

        expect(service.isInitialized, true);
      });

      test('double initialize is idempotent', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final container = client.services!;

        await container.initialize();
        await container.initialize();

        expect(container.isInitialized, true);
      });

      test('dispose then get recreates service', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
        });

        final first = client.getService<LoggingService>();
        await client.services!.dispose<LoggingService>();

        final second = client.getService<LoggingService>();

        expect(second, isNot(same(first)));
        expect(second.isDisposed, false);
      });

      test('unregister removes registration and instance', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
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
          container.register<Level5Service>((_) => Level5Service());
          container.register<Level4Service>((_) => Level4Service());
          container.register<Level3Service>((_) => Level3Service());
          container.register<Level2Service>((_) => Level2Service());
          container.register<Level1Service>((_) => Level1Service());
        });

        final level1 = client.getService<Level1Service>();
        expect(level1.level2.level3.level4.level5, isA<Level5Service>());
      });

      test('diamond dependency resolves to single instance', () async {
        await client.initServices((container) {
          container.register<DiamondD>((_) => DiamondD());
          container.register<DiamondB>((_) => DiamondB());
          container.register<DiamondC>((_) => DiamondC());
          container.register<DiamondA>((_) => DiamondA());
        });

        final a = client.getService<DiamondA>();

        expect(a.b.d, same(a.c.d));
      });
    });

    group('Memory Safety', () {
      test('disposed container clears all references', () async {
        await client.initServices((container) {
          container.register<LoggingService>((_) => LoggingService());
          container.register<ApiClient>((_) => ApiClient());
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
        container.registerFactory<RequestService>((_) => RequestService());
      });

      final req1 = client.services!.create<RequestService>();
      final req2 = client.services!.create<RequestService>();
      final req3 = client.services!.create<RequestService>();

      expect(req1, isNot(same(req2)));
      expect(req2, isNot(same(req3)));

      expect(req1.instanceId, 1);
      expect(req2.instanceId, 2);
      expect(req3.instanceId, 3);
    });

    test('factory instances are not cached', () async {
      await client.initServices((container) {
        container.registerFactory<RequestService>((_) => RequestService());
      });

      final instances = List.generate(
        100,
        (_) => client.services!.create<RequestService>(),
      );

      final uniqueIds = instances.map((i) => i.instanceId).toSet();
      expect(uniqueIds.length, 100);
    });

    test('factory can receive parameters via closure', () async {
      await client.initServices((container) {
        container.registerFactory<FormValidator>(
          (_) => FormValidator('form-${FormValidator.instanceCounter + 1}'),
        );
      });

      final v1 = client.services!.create<FormValidator>();
      final v2 = client.services!.create<FormValidator>();

      expect(v1.formId, 'form-1');
      expect(v2.formId, 'form-2');
    });

    test('factory throws ServiceNotFoundException if not registered', () async {
      await client.initServices((container) {});

      expect(
        () => client.services!.create<RequestService>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('factory can depend on singletons', () async {
      await client.initServices((container) {
        container.register<LoggingService>((_) => LoggingService());
        container.registerFactory<ApiRequestService>(
            (_) => ApiRequestService());
      });

      final req1 = client.services!.create<ApiRequestService>();
      final req2 = client.services!.create<ApiRequestService>();

      expect(req1, isNot(same(req2)));
      expect(req1.logger, same(req2.logger));
    });

    test('factory instances are NOT auto-disposed', () async {
      await client.initServices((container) {
        container.registerFactory<RequestService>((_) => RequestService());
      });

      final req = client.services!.create<RequestService>();

      await client.services!.disposeAll();

      expect(req.isDisposed, false);
    });

    test('factory vs singleton comparison', () async {
      await client.initServices((container) {
        container.register<LoggingService>((_) => LoggingService());
        container.registerFactory<RequestService>((_) => RequestService());
      });

      final log1 = client.getService<LoggingService>();
      final log2 = client.getService<LoggingService>();
      expect(log1, same(log2));

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
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
        container.registerNamed<TenantApiClient>(
          'globex',
          (_) => TenantApiClient(tenantId: 'globex', baseUrl: 'api.globex.com'),
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
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
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
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
      });

      expect(
        () => client.services!.getSync<TenantApiClient>(name: 'nonexistent'),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('named services can coexist with unnamed singleton', () async {
      await client.initServices((container) {
        container.register<TenantApiClient>(
          (_) =>
              TenantApiClient(tenantId: 'default', baseUrl: 'api.default.com'),
        );
        container.registerNamed<TenantApiClient>(
          'acme',
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
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
          (_) => LoggingService(),
        );
        container.registerNamed<LoggingService>(
          'debug',
          (_) => LoggingService(),
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
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
        );
        container.registerNamed<TenantApiClient>(
          'globex',
          (_) => TenantApiClient(tenantId: 'globex', baseUrl: 'api.globex.com'),
        );
      });

      client.services!.getSync<TenantApiClient>(name: 'acme');
      client.services!.getSync<TenantApiClient>(name: 'globex');

      await client.services!.unregister<TenantApiClient>(name: 'acme');

      expect(
        () => client.services!.getSync<TenantApiClient>(name: 'acme'),
        throwsA(isA<ServiceNotFoundException>()),
      );

      final globex = client.services!.getSync<TenantApiClient>(name: 'globex');
      expect(globex.tenantId, 'globex');
    });

    test('child scope inherits named registrations from parent', () async {
      await client.initServices((container) {
        container.registerNamed<TenantApiClient>(
          'acme',
          (_) => TenantApiClient(tenantId: 'acme', baseUrl: 'api.acme.com'),
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
          (_) => TenantApiClient(tenantId: 'acme-parent', baseUrl: 'parent.com'),
        );
      });

      final parentAcme =
          client.services!.getSync<TenantApiClient>(name: 'acme');

      final childScope = client.services!.createScope();
      childScope.registerNamed<TenantApiClient>(
        'acme',
        (_) => TenantApiClient(tenantId: 'acme-child', baseUrl: 'child.com'),
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
          (_) => FormValidator('login'),
          name: 'login',
        );
        container.registerFactory<FormValidator>(
          (_) => FormValidator('signup'),
          name: 'signup',
        );
      });

      final login1 = client.services!.create<FormValidator>(name: 'login');
      final login2 = client.services!.create<FormValidator>(name: 'login');
      final signup = client.services!.create<FormValidator>(name: 'signup');

      expect(login1, isNot(same(login2)));

      expect(login1.formId, 'login');
      expect(signup.formId, 'signup');
    });

    test('named factory throws if name not registered', () async {
      await client.initServices((container) {
        container.registerFactory<FormValidator>(
          (_) => FormValidator('default'),
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

// Deep dependency chain services
class Level5Service extends Service {}

class Level4Service extends Service {
  late final Level5Service level5;

  @override
  Future<void> onInit() async {
    level5 = ref.getSync<Level5Service>();
  }
}

class Level3Service extends Service {
  late final Level4Service level4;

  @override
  Future<void> onInit() async {
    level4 = ref.getSync<Level4Service>();
  }
}

class Level2Service extends Service {
  late final Level3Service level3;

  @override
  Future<void> onInit() async {
    level3 = ref.getSync<Level3Service>();
  }
}

class Level1Service extends Service {
  late final Level2Service level2;

  @override
  Future<void> onInit() async {
    level2 = ref.getSync<Level2Service>();
  }
}

// Diamond dependency services
class DiamondD extends Service {}

class DiamondB extends Service {
  late final DiamondD d;

  @override
  Future<void> onInit() async {
    d = ref.getSync<DiamondD>();
  }
}

class DiamondC extends Service {
  late final DiamondD d;

  @override
  Future<void> onInit() async {
    d = ref.getSync<DiamondD>();
  }
}

class DiamondA extends Service {
  late final DiamondB b;
  late final DiamondC c;

  @override
  Future<void> onInit() async {
    b = ref.getSync<DiamondB>();
    c = ref.getSync<DiamondC>();
  }
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

// Factory with singleton dependency
class ApiRequestService extends Service {
  late final LoggingService logger;
  static int requestCounter = 0;
  final int requestId;

  ApiRequestService() : requestId = ++requestCounter;

  @override
  Future<void> onInit() async {
    logger = ref.getSync<LoggingService>();
  }
}
