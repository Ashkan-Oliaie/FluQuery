import 'package:flutter_test/flutter_test.dart';
import 'package:fluquery/fluquery.dart';

void main() {
  group('QueryState', () {
    test('initial state has correct defaults', () {
      final state = QueryState<String, Object>.initial();

      expect(state.status, QueryStatus.pending);
      expect(state.fetchStatus, FetchStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isPending, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
    });

    test('withSuccess updates state correctly', () {
      final initial = QueryState<String, Object>.initial();
      final updated = initial.withSuccess('hello');

      expect(updated.status, QueryStatus.success);
      expect(updated.data, 'hello');
      expect(updated.isSuccess, isTrue);
      expect(updated.hasData, isTrue);
    });

    test('withError updates state correctly', () {
      final initial = QueryState<String, Object>.initial();
      final updated = initial.withError('error occurred');

      expect(updated.status, QueryStatus.error);
      expect(updated.error, 'error occurred');
      expect(updated.isError, isTrue);
    });
  });

  group('MutationState', () {
    test('initial state has correct defaults', () {
      final state = MutationState<String, Object, String, void>.initial();

      expect(state.status, MutationStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.isIdle, isTrue);
      expect(state.isPending, isFalse);
    });
  });

  group('StaleTime', () {
    test('zero stale time considers data immediately stale', () {
      const staleTime = StaleTime.zero;
      final dataUpdatedAt =
          DateTime.now().subtract(const Duration(milliseconds: 1));

      expect(staleTime.isStale(dataUpdatedAt), isTrue);
    });

    test('infinity stale time never considers data stale', () {
      const staleTime = StaleTime.infinity;
      final dataUpdatedAt = DateTime.now().subtract(const Duration(days: 365));

      expect(staleTime.isStale(dataUpdatedAt), isFalse);
    });

    test('custom stale time works correctly', () {
      const staleTime = StaleTime(Duration(minutes: 5));

      // Data from 1 minute ago is not stale
      final recentData = DateTime.now().subtract(const Duration(minutes: 1));
      expect(staleTime.isStale(recentData), isFalse);

      // Data from 10 minutes ago is stale
      final oldData = DateTime.now().subtract(const Duration(minutes: 10));
      expect(staleTime.isStale(oldData), isTrue);
    });
  });

  group('CancellationToken', () {
    test('initially not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel sets isCancelled to true', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('listeners are called on cancel', () {
      final token = CancellationToken();
      var called = false;

      token.addListener(() => called = true);
      expect(called, isFalse);

      token.cancel();
      expect(called, isTrue);
    });
  });

  group('QueryKeyUtils', () {
    test('same query keys produce same hash', () {
      final hash1 = QueryKeyUtils.hashKey(['todos', 1]);
      final hash2 = QueryKeyUtils.hashKey(['todos', 1]);

      expect(hash1, equals(hash2));
    });

    test('different query keys produce different hashes', () {
      final hash1 = QueryKeyUtils.hashKey(['todos', 1]);
      final hash2 = QueryKeyUtils.hashKey(['todos', 2]);

      expect(hash1, isNot(equals(hash2)));
    });

    test('equals compares keys correctly', () {
      expect(QueryKeyUtils.equals(['todos', 1], ['todos', 1]), isTrue);
      expect(QueryKeyUtils.equals(['todos', 1], ['todos', 2]), isFalse);
    });

    test('matchesFilter works correctly', () {
      expect(QueryKeyUtils.matchesFilter(['todos', 1], ['todos']), isTrue);
      expect(QueryKeyUtils.matchesFilter(['todos', 1], ['todos', 1]), isTrue);
      expect(QueryKeyUtils.matchesFilter(['todos', 1], ['users']), isFalse);
    });
  });

  group('FluQueryLogger', () {
    test('level can be set', () {
      FluQueryLogger.level = LogLevel.debug;
      expect(FluQueryLogger.level, LogLevel.debug);

      FluQueryLogger.level = LogLevel.warn;
      expect(FluQueryLogger.level, LogLevel.warn);
    });
  });
}
