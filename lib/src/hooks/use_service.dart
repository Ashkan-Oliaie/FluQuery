import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/service/services.dart';
import 'use_query_client.dart';

/// Access a service from the container.
T useService<T extends Service>({String? key}) {
  final client = useQueryClient();
  final services = client.services;

  if (services == null) {
    throw StateError(
      'useService<$T>() called but QueryClient has no ServiceContainer.',
    );
  }

  return useMemoized(
    () => services.getSync<T>(name: key),
    [services, key],
  );
}

/// Select state from a [StatefulService]. Only rebuilds when selected value changes.
///
/// Unfortunately Dart requires all 3 type parameters because it can't infer
/// TState from TService. The selector parameter type helps with R inference.
///
/// ```dart
/// final count = useSelect<TaskService, TaskState, int>(
///   (s) => s.completedCount,
///   key: kTaskService,
/// );
/// ```
R useSelect<TService extends StatefulService<TState>, TState, R>(
  R Function(TState state) selector, {
  String? key,
}) {
  final service = useService<TService>(key: key);

  final selectorListenable = useMemoized(
    () => service.select(selector),
    [service],
  );

  useEffect(() {
    return () {
      if (selectorListenable is ChangeNotifier) {
        (selectorListenable as ChangeNotifier).dispose();
      }
    };
  }, [selectorListenable]);

  return useValueListenable(selectorListenable);
}

/// Select a single item by ID. Only rebuilds when that item changes.
T? useSelectItem<TService extends StatefulService<TState>, TState, T, TId>(
  List<T> Function(TState state) listSelector,
  TId id,
  TId Function(T item) getId, {
  String? key,
}) {
  final service = useService<TService>(key: key);

  final selectorListenable = useMemoized(
    () => service.select((state) {
      final list = listSelector(state);
      try {
        return list.firstWhere((item) => getId(item) == id);
      } catch (_) {
        return null;
      }
    }),
    [service, id],
  );

  useEffect(() {
    return () {
      if (selectorListenable is ChangeNotifier) {
        (selectorListenable as ChangeNotifier).dispose();
      }
    };
  }, [selectorListenable]);

  return useValueListenable(selectorListenable);
}

/// Select only IDs from a list. Only rebuilds when items added/removed/reordered.
List<TId>
    useSelectIds<TService extends StatefulService<TState>, TState, T, TId>(
  List<T> Function(TState state) listSelector,
  TId Function(T item) getId, {
  String? key,
}) {
  return useSelect<TService, TState, List<TId>>(
    (state) => listSelector(state).map(getId).toList(),
    key: key,
  );
}
