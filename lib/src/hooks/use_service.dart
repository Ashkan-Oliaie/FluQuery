import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/service/services.dart';
import '../widgets/viewmodel_provider.dart';
import 'use_query_client.dart';

// ============================================================
// CORE SERVICE HOOKS
// ============================================================

/// Hook to access a singleton service from the [ServiceContainer].
///
/// Example:
/// ```dart
/// final auth = useService<AuthService>();
/// auth.login(email, password);
/// ```
T useService<T extends Service>() {
  final client = useQueryClient();
  final services = client.services;

  if (services == null) {
    throw StateError(
      'useService<$T>() called but QueryClient has no ServiceContainer.',
    );
  }

  return useMemoized(() => services.getSync<T>(), [services]);
}

/// Hook to select state from a singleton [StatefulService].
///
/// Only rebuilds when the selected value changes.
///
/// Example:
/// ```dart
/// // Select from global CartService
/// final itemCount = useSelect<CartService, CartState, int>((s) => s.items.length);
/// final isLoading = useSelect<CartService, CartState, bool>((s) => s.isLoading);
/// ```
R useSelect<TService extends StatefulService<TState>, TState, R>(
  R Function(TState state) selector,
) {
  final service = useService<TService>();

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

// ============================================================
// VIEWMODEL HOOKS - For ViewModelProvider scoped services
// ============================================================

/// Hook to get a ViewModel from [ViewModelProvider].
///
/// Example:
/// ```dart
/// final vm = useViewModel<TaskViewModel>(context);
/// vm.addTask('New task');
/// ```
T useViewModel<T extends Service>(BuildContext context) {
  return useMemoized(
    () => ViewModelProvider.of<T>(context),
    [context],
  );
}

/// Hook to select state from a ViewModel [StatefulService].
///
/// Only rebuilds when the selected value changes.
///
/// Example:
/// ```dart
/// final isLoading = useViewModelSelect<TaskViewModel, TaskState, bool>(
///   context, (s) => s.isLoading,
/// );
/// final tasks = useViewModelSelect<TaskViewModel, TaskState, List<Task>>(
///   context, (s) => s.filteredTasks,
/// );
/// ```
R useViewModelSelect<TService extends StatefulService<TState>, TState, R>(
  BuildContext context,
  R Function(TState state) selector,
) {
  final service = useViewModel<TService>(context);

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
