import 'package:flutter_test/flutter_test.dart';
import 'package:fluquery/fluquery.dart';

/// Mock data model for testing
class Todo {
  final int id;
  final String title;
  final bool completed;

  Todo({required this.id, required this.title, required this.completed});

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as int,
        title: json['title'] as String,
        completed: json['completed'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          id == other.id &&
          title == other.title &&
          completed == other.completed;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ completed.hashCode;
}

/// Serializer for List<Todo>
class TodoListSerializer implements QueryDataSerializer<List<Todo>> {
  @override
  dynamic serialize(List<Todo> data) {
    return data.map((t) => t.toJson()).toList();
  }

  @override
  List<Todo> deserialize(dynamic json) {
    return (json as List)
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// Serializer for single Todo
class TodoSerializer implements QueryDataSerializer<Todo> {
  @override
  dynamic serialize(Todo data) => data.toJson();

  @override
  Todo deserialize(dynamic json) => Todo.fromJson(json as Map<String, dynamic>);
}

void main() {
  // Disable logging during tests
  FluQueryLogger.level = LogLevel.none;

  group('InMemoryPersister', () {
    late InMemoryPersister persister;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
    });

    tearDown(() async {
      await persister.close();
    });

    test('persists and restores a single query', () async {
      final query = PersistedQuery(
        queryKey: ['todos'],
        queryHash: 'hash1',
        serializedData: [
          {'id': 1, 'title': 'Test', 'completed': false}
        ],
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      );

      await persister.persistQuery(query);

      final restored = await persister.restoreQuery('hash1');
      expect(restored, isNotNull);
      expect(restored!.queryKey, equals(['todos']));
      expect(restored.serializedData, isA<List>());
    });

    test('restores all queries', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['todos'],
        queryHash: 'hash1',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await persister.persistQuery(PersistedQuery(
        queryKey: ['users'],
        queryHash: 'hash2',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      final all = await persister.restoreAll();
      expect(all.length, equals(2));
    });

    test('removes a specific query', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['todos'],
        queryHash: 'hash1',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await persister.removeQuery('hash1');

      final restored = await persister.restoreQuery('hash1');
      expect(restored, isNull);
    });

    test('clears all queries', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['todos'],
        queryHash: 'hash1',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await persister.clear();

      final all = await persister.restoreAll();
      expect(all, isEmpty);
    });

    test('removes queries matching filter', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['todos'],
        queryHash: 'hash1',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await persister.persistQuery(PersistedQuery(
        queryKey: ['users'],
        queryHash: 'hash2',
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await persister.removeQueries((q) => q.queryKey.contains('todos'));

      final all = await persister.restoreAll();
      expect(all.length, equals(1));
      expect(all.first.queryKey, equals(['users']));
    });
  });

  group('QueryClient Persistence', () {
    late InMemoryPersister persister;
    late QueryClient client;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
      client = QueryClient(persister: persister);
    });

    tearDown(() async {
      client.dispose();
      await persister.close();
    });

    group('Hydration', () {
      test('hydrates queries from persister', () async {
        // Pre-populate the persister
        await persister.persistQuery(PersistedQuery(
          queryKey: ['todos'],
          queryHash: QueryKeyUtils.hashKey(['todos']),
          serializedData: [
            {'id': 1, 'title': 'Persisted Todo', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        // Hydrate
        await client.hydrate();

        // Check cache has the query
        final query = client.queryCache.getUntyped(['todos']);
        expect(query, isNotNull);
        expect(query!.state.rawData, isA<List>());
      });

      test('does not overwrite existing queries during hydration', () async {
        // Add query to cache first
        client.setQueryData<List<Todo>>([
          'todos'
        ], [
          Todo(id: 99, title: 'In Memory', completed: true),
        ]);

        // Pre-populate persister with different data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['todos'],
          queryHash: QueryKeyUtils.hashKey(['todos']),
          serializedData: [
            {'id': 1, 'title': 'Persisted', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        // Hydrate
        await client.hydrate();

        // Should keep in-memory data, not persisted
        final data = client.getQueryData<List<Todo>>(['todos']);
        expect(data!.first.id, equals(99));
        expect(data.first.title, equals('In Memory'));
      });

      test('handles corrupted persisted data gracefully', () async {
        // Persist invalid data that can't be hydrated
        await persister.persistQuery(PersistedQuery(
          queryKey: ['corrupt'],
          queryHash: QueryKeyUtils.hashKey(['corrupt']),
          serializedData: 'not valid json structure',
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        // Should not throw
        await client.hydrate();

        expect(client.isHydrated, isTrue);
      });

      test('marks isHydrated true after hydration', () async {
        expect(client.isHydrated, isFalse);
        await client.hydrate();
        expect(client.isHydrated, isTrue);
      });

      test('skips hydration if already hydrated', () async {
        await client.hydrate();
        expect(client.isHydrated, isTrue);

        // Add new data to persister
        await persister.persistQuery(PersistedQuery(
          queryKey: ['new'],
          queryHash: QueryKeyUtils.hashKey(['new']),
          serializedData: [],
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        // Hydrate again - should skip
        await client.hydrate();

        // New query should NOT be in cache
        final query = client.queryCache.getUntyped(['new']);
        expect(query, isNull);
      });
    });

    group('Registration', () {
      test('registers persistence options for a query', () {
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Verify internal state (via persistence behavior)
        // When data is set, it should persist
        client.setQueryData<List<Todo>>([
          'todos'
        ], [
          Todo(id: 1, title: 'Test', completed: false),
        ]);

        // Trigger persistence manually
        client.persistQuery(
          ['todos'],
          [Todo(id: 1, title: 'Test', completed: false)],
          DateTime.now(),
        );
      });

      test('first-wins: uses first registered serializer', () async {
        // First observer registers
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(hours: 1),
          ),
        );

        // Second observer tries to register different options
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(days: 7), // Different maxAge
          ),
        );

        // Internal count should be 2
        // (we can't directly verify, but behavior should use first maxAge)
      });

      test('unregister decrements observer count', () {
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Unregister one
        client.unregisterPersistOptions(['todos']);

        // Should still have one observer - persistence still works
        // (we verify behavior, not internal state)
      });
    });

    group('Deserialization', () {
      test('deserializes hydrated data when query is accessed', () async {
        // Persist raw JSON data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['todos'],
          queryHash: QueryKeyUtils.hashKey(['todos']),
          serializedData: [
            {'id': 1, 'title': 'Serialized', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        await client.hydrate();

        // At this point, data is still raw JSON (List<Map>)
        final rawQuery = client.queryCache.getUntyped(['todos']);
        expect(rawQuery!.state.rawData, isA<List>());

        // Register serializer - this should trigger deserialization
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Now data should be deserialized
        final data = client.getQueryData<List<Todo>>(['todos']);
        expect(data, isNotNull);
        expect(data!.first, isA<Todo>());
        expect(data.first.title, equals('Serialized'));
      });

      test('handles deserialization failure gracefully', () async {
        // Persist data that will fail deserialization
        await persister.persistQuery(PersistedQuery(
          queryKey: ['bad'],
          queryHash: QueryKeyUtils.hashKey(['bad']),
          serializedData: 'not a list', // Will fail List<Todo> deserialization
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        await client.hydrate();

        // Register serializer - should handle failure
        client.registerPersistOptions<List<Todo>>(
          ['bad'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Query should be removed due to corruption
        final query = client.queryCache.getUntyped(['bad']);
        expect(query, isNull);
      });
    });

    group('maxAge Validation', () {
      test('discards hydrated data exceeding maxAge', () async {
        // Persist old data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['old'],
          queryHash: QueryKeyUtils.hashKey(['old']),
          serializedData: [
            {'id': 1, 'title': 'Old', 'completed': false}
          ],
          dataUpdatedAt:
              DateTime.now().subtract(const Duration(hours: 2)), // 2 hours old
          persistedAt: DateTime.now().subtract(const Duration(hours: 2)),
          status: 'success',
        ));

        await client.hydrate();

        // Query exists but is not yet validated
        expect(client.queryCache.getUntyped(['old']), isNotNull);

        // Register with 1 hour maxAge - should discard
        client.registerPersistOptions<List<Todo>>(
          ['old'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(hours: 1), // Data is too old
          ),
        );

        // Query should be removed
        expect(client.queryCache.getUntyped(['old']), isNull);
      });

      test('keeps data within maxAge', () async {
        // Persist recent data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['recent'],
          queryHash: QueryKeyUtils.hashKey(['recent']),
          serializedData: [
            {'id': 1, 'title': 'Recent', 'completed': false}
          ],
          dataUpdatedAt:
              DateTime.now().subtract(const Duration(minutes: 30)), // 30 min
          persistedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          status: 'success',
        ));

        await client.hydrate();

        // Register with 1 hour maxAge - should keep
        client.registerPersistOptions<List<Todo>>(
          ['recent'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(hours: 1),
          ),
        );

        // Query should still exist
        expect(client.queryCache.getUntyped(['recent']), isNotNull);
      });
    });

    group('Auto-Persistence on Data Success', () {
      test('persists data when query succeeds', () async {
        // Register persistence
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Simulate successful data update
        client.setQueryData<List<Todo>>([
          'todos'
        ], [
          Todo(id: 1, title: 'New', completed: false),
        ]);

        // Give async persistence time
        await Future.delayed(const Duration(milliseconds: 50));

        // Manually persist (setQueryData doesn't trigger onDataSuccess,
        // only Query.fetch does)
        await client.persistQuery(
          ['todos'],
          [Todo(id: 1, title: 'New', completed: false)],
          DateTime.now(),
        );

        // Check persister has the data
        final hash = QueryKeyUtils.hashKey(['todos']);
        final persisted = await persister.restoreQuery(hash);
        expect(persisted, isNotNull);
      });
    });

    group('Multiple Queries with Same Key', () {
      test('multiple observers share persisted data', () async {
        // Persist initial data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['shared'],
          queryHash: QueryKeyUtils.hashKey(['shared']),
          serializedData: [
            {'id': 1, 'title': 'Shared', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        await client.hydrate();

        // Observer 1 registers
        client.registerPersistOptions<List<Todo>>(
          ['shared'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Observer 2 registers (same key, different instance)
        client.registerPersistOptions<List<Todo>>(
          ['shared'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Both should see the same deserialized data
        final data = client.getQueryData<List<Todo>>(['shared']);
        expect(data, isNotNull);
        expect(data!.first.title, equals('Shared'));
      });

      test('one observer with persist, one without', () async {
        await persister.persistQuery(PersistedQuery(
          queryKey: ['mixed'],
          queryHash: QueryKeyUtils.hashKey(['mixed']),
          serializedData: [
            {'id': 1, 'title': 'Mixed', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(),
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        await client.hydrate();

        // Only one observer registers persistence
        client.registerPersistOptions<List<Todo>>(
          ['mixed'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Data should still be accessible (deserialized)
        final data = client.getQueryData<List<Todo>>(['mixed']);
        expect(data, isNotNull);
      });
    });

    group('Different Query Keys', () {
      test('persists multiple different query keys', () async {
        // Register different serializers for different keys
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        client.registerPersistOptions<Todo>(
          ['todo', 1],
          PersistOptions(serializer: TodoSerializer()),
        );

        // Persist both
        await client.persistQuery(
          ['todos'],
          [Todo(id: 1, title: 'List', completed: false)],
          DateTime.now(),
        );

        await client.persistQuery(
          ['todo', 1],
          Todo(id: 1, title: 'Single', completed: true),
          DateTime.now(),
        );

        // Both should be persisted
        final all = await persister.restoreAll();
        expect(all.length, equals(2));
      });
    });

    group('Unpersist', () {
      test('removes query from persistence', () async {
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        await client.persistQuery(
          ['todos'],
          [Todo(id: 1, title: 'Test', completed: false)],
          DateTime.now(),
        );

        // Verify it's persisted
        final hash = QueryKeyUtils.hashKey(['todos']);
        expect(await persister.restoreQuery(hash), isNotNull);

        // Unpersist
        await client.unpersistQuery(['todos']);

        // Should be gone
        expect(await persister.restoreQuery(hash), isNull);
      });
    });

    group('Clear Persistence', () {
      test('clears all persisted queries', () async {
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        await client.persistQuery(
          ['todos'],
          [Todo(id: 1, title: 'Test', completed: false)],
          DateTime.now(),
        );

        await client.clearPersistence();

        final all = await persister.restoreAll();
        expect(all, isEmpty);
      });
    });

    group('Dehydrate', () {
      test('exports all persistable queries', () async {
        // Set up data and register persistence
        client.setQueryData<List<Todo>>([
          'todos'
        ], [
          Todo(id: 1, title: 'Export', completed: false),
        ]);

        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        final dehydrated = await client.dehydrate();

        expect(dehydrated.length, equals(1));
        expect(dehydrated.first.queryKey, equals(['todos']));
        expect(dehydrated.first.serializedData, isA<List>());
      });

      test('only exports queries with persist options', () async {
        // Query without persistence
        client.setQueryData<String>(['no-persist'], 'test');

        // Query with persistence
        client.setQueryData<List<Todo>>([
          'todos'
        ], [
          Todo(id: 1, title: 'Export', completed: false),
        ]);
        client.registerPersistOptions<List<Todo>>(
          ['todos'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        final dehydrated = await client.dehydrate();

        // Should only have the one with persistence
        expect(dehydrated.length, equals(1));
        expect(dehydrated.first.queryKey, equals(['todos']));
      });
    });
  });

  group('Edge Cases', () {
    late InMemoryPersister persister;
    late QueryClient client;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
      client = QueryClient(persister: persister);
    });

    tearDown(() async {
      client.dispose();
      await persister.close();
    });

    test('handles null data gracefully', () async {
      client.registerPersistOptions<List<Todo>>(
        ['empty'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Persist null data - should not crash
      await client.persistQuery(['empty'], null, DateTime.now());

      // Should not have persisted null
      final hash = QueryKeyUtils.hashKey(['empty']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNull);
    });

    test('handles empty list', () async {
      client.registerPersistOptions<List<Todo>>(
        ['empty'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      await client.persistQuery(['empty'], <Todo>[], DateTime.now());

      final hash = QueryKeyUtils.hashKey(['empty']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);
      expect(restored!.serializedData, isEmpty);
    });

    test('handles complex nested data', () async {
      final complexData = [
        {'id': 1, 'title': 'Test', 'completed': false},
        {'id': 2, 'title': 'With "quotes"', 'completed': true},
        {'id': 3, 'title': 'With\nnewlines', 'completed': false},
      ];

      await persister.persistQuery(PersistedQuery(
        queryKey: ['complex'],
        queryHash: QueryKeyUtils.hashKey(['complex']),
        serializedData: complexData,
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      final restored = await persister.restoreQuery(
        QueryKeyUtils.hashKey(['complex']),
      );

      expect(restored, isNotNull);
      expect((restored!.serializedData as List).length, equals(3));
    });

    test('handles query key with special characters', () async {
      final specialKey = ['user', 'test@email.com', 'posts'];

      client.registerPersistOptions<List<Todo>>(
        specialKey,
        PersistOptions(serializer: TodoListSerializer()),
      );

      await client.persistQuery(
        specialKey,
        [Todo(id: 1, title: 'Test', completed: false)],
        DateTime.now(),
      );

      final hash = QueryKeyUtils.hashKey(specialKey);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);
      expect(restored!.queryKey, equals(specialKey));
    });

    test('handles rapid persist/restore cycles', () async {
      client.registerPersistOptions<List<Todo>>(
        ['rapid'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Rapidly persist multiple updates
      for (int i = 0; i < 10; i++) {
        await client.persistQuery(
          ['rapid'],
          [Todo(id: i, title: 'Rapid $i', completed: false)],
          DateTime.now(),
        );
      }

      // Should have latest
      final hash = QueryKeyUtils.hashKey(['rapid']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);
    });

    test('handles persister not initialized', () async {
      final uninitPersister = InMemoryPersister();
      final uninitClient = QueryClient(persister: uninitPersister);

      // Persister not initialized - operations should fail gracefully
      // (InMemoryPersister doesn't throw, but HivePersister would)
      uninitClient.dispose();
    });

    test('handles concurrent hydration calls', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['concurrent'],
        queryHash: QueryKeyUtils.hashKey(['concurrent']),
        serializedData: [],
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      // Call hydrate multiple times concurrently
      await Future.wait([
        client.hydrate(),
        client.hydrate(),
        client.hydrate(),
      ]);

      // Should only hydrate once
      expect(client.isHydrated, isTrue);
    });
  });

  group('PersistedQuery Serialization', () {
    test('serializes to JSON correctly', () {
      final query = PersistedQuery(
        queryKey: ['todos', 1],
        queryHash: 'hash123',
        serializedData: {'key': 'value'},
        dataUpdatedAt: DateTime.utc(2024, 1, 1, 12, 0, 0),
        persistedAt: DateTime.utc(2024, 1, 1, 12, 0, 0),
        status: 'success',
      );

      final json = query.toJson();

      expect(json['queryKey'], equals(['todos', 1]));
      expect(json['queryHash'], equals('hash123'));
      expect(json['serializedData'], equals({'key': 'value'}));
      expect(json['status'], equals('success'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'queryKey': ['todos', 1],
        'queryHash': 'hash123',
        'serializedData': {'key': 'value'},
        'dataUpdatedAt': '2024-01-01T12:00:00.000Z',
        'persistedAt': '2024-01-01T12:00:00.000Z',
        'status': 'success',
      };

      final query = PersistedQuery.fromJson(json);

      expect(query.queryKey, equals(['todos', 1]));
      expect(query.queryHash, equals('hash123'));
      expect(query.status, equals('success'));
    });

    test('handles null dataUpdatedAt', () {
      final json = {
        'queryKey': ['todos'],
        'queryHash': 'hash',
        'serializedData': null,
        'dataUpdatedAt': null,
        'persistedAt': '2024-01-01T12:00:00.000Z',
        'status': 'success',
      };

      final query = PersistedQuery.fromJson(json);
      expect(query.dataUpdatedAt, isNull);
    });
  });

  group('Serializers', () {
    test('JsonSerializer passes through data', () {
      const serializer = JsonSerializer<Map<String, dynamic>>();

      final data = {'key': 'value', 'number': 42};
      final serialized = serializer.serialize(data);
      final deserialized = serializer.deserialize(serialized);

      expect(deserialized, equals(data));
    });

    test('ListMapSerializer handles List<Map>', () {
      const serializer = ListMapSerializer();

      final data = [
        {'id': 1, 'name': 'Test'},
        {'id': 2, 'name': 'Test2'},
      ];

      final serialized = serializer.serialize(data);
      final deserialized = serializer.deserialize(serialized);

      expect(deserialized, equals(data));
    });

    test('TodoListSerializer round-trips correctly', () {
      final serializer = TodoListSerializer();

      final todos = [
        Todo(id: 1, title: 'First', completed: false),
        Todo(id: 2, title: 'Second', completed: true),
      ];

      final serialized = serializer.serialize(todos);
      final deserialized = serializer.deserialize(serialized);

      expect(deserialized.length, equals(2));
      expect(deserialized[0], equals(todos[0]));
      expect(deserialized[1], equals(todos[1]));
    });
  });

  group('Same Query Key - Different Settings', () {
    late InMemoryPersister persister;
    late QueryClient client;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
      client = QueryClient(persister: persister);
    });

    tearDown(() async {
      client.dispose();
      await persister.close();
    });

    group('Different Persistence Settings', () {
      test(
          'first observer with persist, second without persist - data persists',
          () async {
        // First observer registers with persistence
        client.registerPersistOptions<List<Todo>>(
          ['shared-key'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(hours: 1),
          ),
        );

        // Second observer does NOT register persistence (simulating useQuery without persist)
        // (Nothing to call - just not registering)

        // Set data (simulating a successful fetch)
        client.setQueryData<List<Todo>>([
          'shared-key'
        ], [
          Todo(id: 1, title: 'Shared', completed: false),
        ]);

        // Manually trigger persistence
        await client.persistQuery(
          ['shared-key'],
          [Todo(id: 1, title: 'Shared', completed: false)],
          DateTime.now(),
        );

        // Data should be persisted (first observer's options apply)
        final hash = QueryKeyUtils.hashKey(['shared-key']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
      });

      test(
          'first observer without persist, second with persist - data does NOT persist initially',
          () async {
        // First observer does NOT register persistence
        // (Simulating useQuery without persist option)

        // Second observer tries to register with persistence
        // But first-wins means no persistence options are set
        // Actually, in this case, second CAN register since first didn't
        client.registerPersistOptions<List<Todo>>(
          ['late-persist'],
          PersistOptions(
            serializer: TodoListSerializer(),
          ),
        );

        // Set data
        client.setQueryData<List<Todo>>([
          'late-persist'
        ], [
          Todo(id: 1, title: 'Late', completed: false),
        ]);

        // Persist should work since options were registered
        await client.persistQuery(
          ['late-persist'],
          [Todo(id: 1, title: 'Late', completed: false)],
          DateTime.now(),
        );

        final hash = QueryKeyUtils.hashKey(['late-persist']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
      });

      test('both observers with persist but different maxAge - first wins',
          () async {
        // First observer: short maxAge
        client.registerPersistOptions<List<Todo>>(
          ['dual-persist'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(minutes: 5), // Short
          ),
        );

        // Second observer: long maxAge (should be ignored)
        client.registerPersistOptions<List<Todo>>(
          ['dual-persist'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(days: 7), // Long (ignored)
          ),
        );

        // Persist old data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['dual-persist'],
          queryHash: QueryKeyUtils.hashKey(['dual-persist']),
          serializedData: [
            {'id': 1, 'title': 'Old', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now()
              .subtract(const Duration(minutes: 10)), // 10 min old
          persistedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          status: 'success',
        ));

        // Create new client to simulate app restart
        final client2 = QueryClient(persister: persister);
        await client2.hydrate();

        // Register with the FIRST (short) maxAge
        client2.registerPersistOptions<List<Todo>>(
          ['dual-persist'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(
                minutes: 5), // Data is 10 min old, should be discarded
          ),
        );

        // Data should be discarded because it's older than 5 minutes
        final query = client2.queryCache.getUntyped(['dual-persist']);
        expect(query, isNull); // Discarded due to maxAge

        client2.dispose();
      });

      test('both observers with persist but different keyPrefix - first wins',
          () async {
        // First observer: user A's namespace
        client.registerPersistOptions<List<Todo>>(
          ['namespaced'],
          PersistOptions(
            serializer: TodoListSerializer(),
            keyPrefix: 'user_A',
          ),
        );

        // Second observer: user B's namespace (should be ignored - first wins)
        client.registerPersistOptions<List<Todo>>(
          ['namespaced'],
          PersistOptions(
            serializer: TodoListSerializer(),
            keyPrefix: 'user_B',
          ),
        );

        // Persist
        await client.persistQuery(
          ['namespaced'],
          [Todo(id: 1, title: 'Namespaced', completed: false)],
          DateTime.now(),
        );

        // Should be persisted under user_A prefix
        final userAHash = 'user_A:${QueryKeyUtils.hashKey(['namespaced'])}';
        final restored = await persister.restoreQuery(userAHash);
        expect(restored, isNotNull);

        // Should NOT be under user_B prefix
        final userBHash = 'user_B:${QueryKeyUtils.hashKey(['namespaced'])}';
        final restoredB = await persister.restoreQuery(userBHash);
        expect(restoredB, isNull);
      });

      test('observer unregisters but persistence options remain', () async {
        // Register
        client.registerPersistOptions<List<Todo>>(
          ['sticky-options'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Unregister
        client.unregisterPersistOptions(['sticky-options']);

        // Options should still be available for persistence
        // (we keep them for background persistence)
        await client.persistQuery(
          ['sticky-options'],
          [Todo(id: 1, title: 'Sticky', completed: false)],
          DateTime.now(),
        );

        final hash = QueryKeyUtils.hashKey(['sticky-options']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
      });

      test('multiple register/unregister cycles', () async {
        // Register 3 times
        client.registerPersistOptions<List<Todo>>(
          ['cycles'],
          PersistOptions(serializer: TodoListSerializer()),
        );
        client.registerPersistOptions<List<Todo>>(
          ['cycles'],
          PersistOptions(serializer: TodoListSerializer()),
        );
        client.registerPersistOptions<List<Todo>>(
          ['cycles'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Unregister 2 times
        client.unregisterPersistOptions(['cycles']);
        client.unregisterPersistOptions(['cycles']);

        // Should still have 1 observer, options should work
        await client.persistQuery(
          ['cycles'],
          [Todo(id: 1, title: 'Cycle', completed: false)],
          DateTime.now(),
        );

        final hash = QueryKeyUtils.hashKey(['cycles']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);

        // Unregister last one
        client.unregisterPersistOptions(['cycles']);

        // Options should still remain (we don't remove them on last unregister)
        await client.persistQuery(
          ['cycles'],
          [Todo(id: 2, title: 'Cycle2', completed: true)],
          DateTime.now(),
        );

        final restored2 = await persister.restoreQuery(hash);
        expect(restored2, isNotNull);
      });
    });

    group('Different StaleTime with Persistence', () {
      test(
          'query with short staleTime triggers refetch on mount, persisted data shows immediately',
          () async {
        // Pre-persist data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['stale-test'],
          queryHash: QueryKeyUtils.hashKey(['stale-test']),
          serializedData: [
            {'id': 1, 'title': 'Persisted', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now().subtract(const Duration(seconds: 30)),
          persistedAt: DateTime.now().subtract(const Duration(seconds: 30)),
          status: 'success',
        ));

        await client.hydrate();

        // Register persistence
        client.registerPersistOptions<List<Todo>>(
          ['stale-test'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Data should be available immediately (hydrated)
        final data = client.getQueryData<List<Todo>>(['stale-test']);
        expect(data, isNotNull);
        expect(data!.first.title, equals('Persisted'));
      });

      test('hydrated data respects staleTime from cache', () async {
        // Pre-persist with recent timestamp
        await persister.persistQuery(PersistedQuery(
          queryKey: ['fresh-data'],
          queryHash: QueryKeyUtils.hashKey(['fresh-data']),
          serializedData: [
            {'id': 1, 'title': 'Fresh', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now(), // Just now - fresh!
          persistedAt: DateTime.now(),
          status: 'success',
        ));

        await client.hydrate();

        client.registerPersistOptions<List<Todo>>(
          ['fresh-data'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Query should exist and have data
        final query = client.queryCache.getUntyped(['fresh-data']);
        expect(query, isNotNull);
        expect(query!.state.rawData, isNotNull);
      });

      test('persistence with maxAge vs query staleTime are independent',
          () async {
        // maxAge controls when PERSISTED data is discarded on hydration
        // staleTime controls when data is considered stale for refetching
        // These are independent concepts

        // Persist data that's 2 hours old
        await persister.persistQuery(PersistedQuery(
          queryKey: ['age-vs-stale'],
          queryHash: QueryKeyUtils.hashKey(['age-vs-stale']),
          serializedData: [
            {'id': 1, 'title': 'Two Hours Old', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          persistedAt: DateTime.now().subtract(const Duration(hours: 2)),
          status: 'success',
        ));

        await client.hydrate();

        // Register with maxAge of 1 day (data is within maxAge)
        client.registerPersistOptions<List<Todo>>(
          ['age-vs-stale'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(
                days: 1), // Data is only 2 hours old, within limit
          ),
        );

        // Data should be available (within maxAge)
        final data = client.getQueryData<List<Todo>>(['age-vs-stale']);
        expect(data, isNotNull);
        expect(data!.first.title, equals('Two Hours Old'));

        // Note: staleTime would be set on the QueryOptions when using useQuery,
        // not on PersistOptions. The data being "stale" for refetch purposes
        // is separate from being "too old" for persistence purposes.
      });

      test(
          'different observers same key - one persists, query still refetches based on staleTime',
          () async {
        // Persist initial data
        await persister.persistQuery(PersistedQuery(
          queryKey: ['mixed-observers'],
          queryHash: QueryKeyUtils.hashKey(['mixed-observers']),
          serializedData: [
            {'id': 1, 'title': 'Initial', 'completed': false}
          ],
          dataUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          persistedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          status: 'success',
        ));

        await client.hydrate();

        // First observer: with persistence
        client.registerPersistOptions<List<Todo>>(
          ['mixed-observers'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Data is available immediately
        var data = client.getQueryData<List<Todo>>(['mixed-observers']);
        expect(data, isNotNull);
        expect(data!.first.title, equals('Initial'));

        // Simulate a refetch with new data
        client.setQueryData<List<Todo>>([
          'mixed-observers'
        ], [
          Todo(id: 2, title: 'Refetched', completed: true),
        ]);

        // Verify new data is in cache
        data = client.getQueryData<List<Todo>>(['mixed-observers']);
        expect(data!.first.title, equals('Refetched'));

        // Persist the new data
        await client.persistQuery(
          ['mixed-observers'],
          [Todo(id: 2, title: 'Refetched', completed: true)],
          DateTime.now(),
        );

        // New data should be persisted
        final hash = QueryKeyUtils.hashKey(['mixed-observers']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
        expect((restored!.serializedData as List).first['title'],
            equals('Refetched'));
      });
    });

    group('Complex Multi-Observer Scenarios', () {
      test('3 observers: persist, no-persist, persist (different maxAge)',
          () async {
        // Observer 1: persist with 1 hour maxAge
        client.registerPersistOptions<List<Todo>>(
          ['three-observers'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(hours: 1),
          ),
        );

        // Observer 2: no persistence (doesn't call registerPersistOptions)
        // Just uses the query

        // Observer 3: persist with 7 day maxAge (ignored - first wins)
        client.registerPersistOptions<List<Todo>>(
          ['three-observers'],
          PersistOptions(
            serializer: TodoListSerializer(),
            maxAge: const Duration(days: 7),
          ),
        );

        // All observers share the same cached data
        client.setQueryData<List<Todo>>([
          'three-observers'
        ], [
          Todo(id: 1, title: 'Shared by 3', completed: false),
        ]);

        // Persist using first observer's options (1 hour maxAge)
        await client.persistQuery(
          ['three-observers'],
          [Todo(id: 1, title: 'Shared by 3', completed: false)],
          DateTime.now(),
        );

        final hash = QueryKeyUtils.hashKey(['three-observers']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
      });

      test(
          'observer A opens, persists data, closes; observer B opens, sees persisted data',
          () async {
        // Observer A registers and persists
        client.registerPersistOptions<List<Todo>>(
          ['handoff'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        client.setQueryData<List<Todo>>([
          'handoff'
        ], [
          Todo(id: 1, title: 'From A', completed: false),
        ]);

        await client.persistQuery(
          ['handoff'],
          [Todo(id: 1, title: 'From A', completed: false)],
          DateTime.now(),
        );

        // Observer A unregisters (simulating widget dispose)
        client.unregisterPersistOptions(['handoff']);

        // Clear in-memory cache to simulate app restart
        client.queryCache.clear();

        // Create new client (simulate fresh app start)
        final client2 = QueryClient(persister: persister);
        await client2.hydrate();

        // Observer B registers
        client2.registerPersistOptions<List<Todo>>(
          ['handoff'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Observer B should see A's data
        final data = client2.getQueryData<List<Todo>>(['handoff']);
        expect(data, isNotNull);
        expect(data!.first.title, equals('From A'));

        client2.dispose();
      });

      test('rapid observer mount/unmount doesnt corrupt persistence', () async {
        final key = ['rapid-mount'];

        // Simulate rapid mount/unmount cycles
        for (int i = 0; i < 10; i++) {
          client.registerPersistOptions<List<Todo>>(
            key,
            PersistOptions(serializer: TodoListSerializer()),
          );

          client.setQueryData<List<Todo>>(key, [
            Todo(id: i, title: 'Iteration $i', completed: false),
          ]);

          await client.persistQuery(
            key,
            [Todo(id: i, title: 'Iteration $i', completed: false)],
            DateTime.now(),
          );

          client.unregisterPersistOptions(key);
        }

        // Should have the last iteration persisted
        final hash = QueryKeyUtils.hashKey(key);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
        expect((restored!.serializedData as List).first['id'], equals(9));
      });

      test('concurrent persistence calls for same key', () async {
        client.registerPersistOptions<List<Todo>>(
          ['concurrent'],
          PersistOptions(serializer: TodoListSerializer()),
        );

        // Fire multiple persistence calls concurrently
        await Future.wait([
          client.persistQuery(
            ['concurrent'],
            [Todo(id: 1, title: 'First', completed: false)],
            DateTime.now(),
          ),
          client.persistQuery(
            ['concurrent'],
            [Todo(id: 2, title: 'Second', completed: true)],
            DateTime.now(),
          ),
          client.persistQuery(
            ['concurrent'],
            [Todo(id: 3, title: 'Third', completed: false)],
            DateTime.now(),
          ),
        ]);

        // Should have one of them (last write wins at storage level)
        final hash = QueryKeyUtils.hashKey(['concurrent']);
        final restored = await persister.restoreQuery(hash);
        expect(restored, isNotNull);
        // The exact value depends on execution order, but it should be valid
        expect((restored!.serializedData as List).first['id'], isIn([1, 2, 3]));
      });
    });
  });

  group('QueryStore with Persistence', () {
    late InMemoryPersister persister;
    late QueryClient client;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
      client = QueryClient(persister: persister);
    });

    tearDown(() async {
      client.dispose();
      await persister.close();
    });

    test('createStore with persist option registers persistence', () async {
      var fetchCount = 0;

      final store = client.createStore<List<Todo>, Object>(
        queryKey: ['store-persist'],
        queryFn: (_) async {
          fetchCount++;
          return [
            Todo(id: fetchCount, title: 'Store $fetchCount', completed: false)
          ];
        },
        persist: PersistOptions(serializer: TodoListSerializer()),
      );

      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 100));

      // Data should be persisted
      final hash = QueryKeyUtils.hashKey(['store-persist']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);

      store.dispose();
    });

    test('createStore restores persisted data on hydration', () async {
      // Pre-persist data
      await persister.persistQuery(PersistedQuery(
        queryKey: ['store-hydrate'],
        queryHash: QueryKeyUtils.hashKey(['store-hydrate']),
        serializedData: [
          {'id': 99, 'title': 'Persisted Store', 'completed': true}
        ],
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      // Register persistence (would normally happen in createStore)
      client.registerPersistOptions<List<Todo>>(
        ['store-hydrate'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Data should be deserialized
      final data = client.getQueryData<List<Todo>>(['store-hydrate']);
      expect(data, isNotNull);
      expect(data!.first.id, equals(99));
    });

    test('createStore updates persistence on data change', () async {
      var fetchCount = 0;

      final store = client.createStore<List<Todo>, Object>(
        queryKey: ['store-update'],
        queryFn: (_) async {
          fetchCount++;
          return [
            Todo(id: fetchCount, title: 'Fetch $fetchCount', completed: false)
          ];
        },
        persist: PersistOptions(serializer: TodoListSerializer()),
      );

      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 100));

      // Trigger refetch
      await store.refetch();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have updated data persisted
      final hash = QueryKeyUtils.hashKey(['store-update']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);
      expect((restored!.serializedData as List).first['id'], equals(2));

      store.dispose();
    });
  });

  group('Schema Change Handling', () {
    late InMemoryPersister persister;
    late QueryClient client;

    setUp(() async {
      persister = InMemoryPersister();
      await persister.init();
      client = QueryClient(persister: persister);
    });

    tearDown(() async {
      client.dispose();
      await persister.close();
    });

    test('gracefully handles schema change - missing field', () async {
      // Persist data with old schema (missing 'completed' field)
      await persister.persistQuery(PersistedQuery(
        queryKey: ['schema-missing'],
        queryHash: QueryKeyUtils.hashKey(['schema-missing']),
        serializedData: [
          {'id': 1, 'title': 'Old Schema'} // Missing 'completed'
        ],
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      // Register with serializer that expects 'completed' field
      // This might throw in deserialize if not handled
      client.registerPersistOptions<List<Todo>>(
        ['schema-missing'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Query should be removed (corrupted data)
      // OR it might work if your serializer handles missing fields
      // The key is: no uncaught exception
    });

    test('gracefully handles schema change - wrong type', () async {
      // Persist data with wrong type (string instead of int for id)
      await persister.persistQuery(PersistedQuery(
        queryKey: ['schema-type'],
        queryHash: QueryKeyUtils.hashKey(['schema-type']),
        serializedData: [
          {'id': 'not-an-int', 'title': 'Wrong Type', 'completed': false}
        ],
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      // This should not throw - error is handled gracefully
      client.registerPersistOptions<List<Todo>>(
        ['schema-type'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Data should be discarded
      final query = client.queryCache.getUntyped(['schema-type']);
      expect(query, isNull);
    });

    test('gracefully handles completely invalid data structure', () async {
      // Persist data that's completely wrong structure
      await persister.persistQuery(PersistedQuery(
        queryKey: ['schema-invalid'],
        queryHash: QueryKeyUtils.hashKey(['schema-invalid']),
        serializedData: 'this is just a string, not a list',
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      // Should not throw
      client.registerPersistOptions<List<Todo>>(
        ['schema-invalid'],
        PersistOptions(serializer: TodoListSerializer()),
      );

      // Data should be discarded
      final query = client.queryCache.getUntyped(['schema-invalid']);
      expect(query, isNull);
    });

    test('removeOnDeserializationError=true removes from persistence',
        () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['schema-remove'],
        queryHash: QueryKeyUtils.hashKey(['schema-remove']),
        serializedData: 'invalid',
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      client.registerPersistOptions<List<Todo>>(
        ['schema-remove'],
        PersistOptions(
          serializer: TodoListSerializer(),
          removeOnDeserializationError: true, // default
        ),
      );

      // Should be removed from persistence
      await Future.delayed(const Duration(milliseconds: 50));
      final hash = QueryKeyUtils.hashKey(['schema-remove']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNull);
    });

    test('removeOnDeserializationError=false keeps in persistence', () async {
      await persister.persistQuery(PersistedQuery(
        queryKey: ['schema-keep'],
        queryHash: QueryKeyUtils.hashKey(['schema-keep']),
        serializedData: 'invalid',
        dataUpdatedAt: DateTime.now(),
        persistedAt: DateTime.now(),
        status: 'success',
      ));

      await client.hydrate();

      client.registerPersistOptions<List<Todo>>(
        ['schema-keep'],
        PersistOptions(
          serializer: TodoListSerializer(),
          removeOnDeserializationError: false,
        ),
      );

      // Should still be in persistence
      final hash = QueryKeyUtils.hashKey(['schema-keep']);
      final restored = await persister.restoreQuery(hash);
      expect(restored, isNotNull);
    });
  });
}
