import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/service/services.dart';
import '../core/query/query.dart';
import 'use_query_client.dart';

/// Hook to access a service from the [ServiceContainer].
///
/// Returns the service instance, creating it lazily if needed.
/// The service is obtained from the [QueryClient]'s service container.
///
/// Example:
/// ```dart
/// class LoginPage extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final auth = useService<AuthService>();
///
///     return ElevatedButton(
///       onPressed: () => auth.login(email, password),
///       child: Text('Login'),
///     );
///   }
/// }
/// ```
///
/// See also:
/// - [useServiceStream] for subscribing to a service's store stream
/// - [Service] for creating custom services
T useService<T extends Service>() {
  final client = useQueryClient();
  final services = client.services;

  if (services == null) {
    throw StateError(
      'useService<$T>() called but QueryClient has no ServiceContainer. '
      'Did you forget to pass a ServiceContainer when creating QueryClient?',
    );
  }

  // Use useMemoized to cache the service reference
  // The service itself is managed by the container
  return useMemoized(() => services.get<T>(), [services]);
}

/// Hook to subscribe to a service and rebuild when a specific value changes.
///
/// [selector] extracts a value from the service that triggers rebuilds.
/// Uses [useStream] internally to subscribe to changes.
///
/// Example:
/// ```dart
/// class UserAvatar extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final user = useServiceSelect<AuthService, User?>(
///       (auth) => auth.userStream,
///       (auth) => auth.currentUser,
///     );
///
///     return CircleAvatar(
///       backgroundImage: user?.avatarUrl != null
///         ? NetworkImage(user!.avatarUrl)
///         : null,
///     );
///   }
/// }
/// ```
R useServiceSelect<T extends Service, R>(
  Stream<R> Function(T service) streamSelector,
  R Function(T service) initialValueSelector,
) {
  final service = useService<T>();
  final stream = useMemoized(() => streamSelector(service), [service]);
  final initialValue = useMemoized(() => initialValueSelector(service), [service]);

  final snapshot = useStream(stream, initialData: initialValue);
  return snapshot.data as R;
}

/// Hook to listen to a service's store and rebuild on changes.
///
/// This is a convenience wrapper around [useServiceSelect] for
/// services that expose a [QueryStore].
///
/// Example:
/// ```dart
/// class UserProfile extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final userState = useServiceStore<AuthService, User?, Object>(
///       (auth) => auth.userStore,
///     );
///
///     if (userState.isLoading) {
///       return CircularProgressIndicator();
///     }
///
///     return Text(userState.data?.name ?? 'Guest');
///   }
/// }
/// ```
QueryState<TData, TError> useServiceStore<T extends Service, TData, TError>(
  QueryStore<TData, TError> Function(T service) storeSelector,
) {
  final service = useService<T>();
  final store = useMemoized(() => storeSelector(service), [service]);

  // Subscribe to store state changes
  final state = useState(store.state);

  useEffect(() {
    final unsubscribe = store.subscribe((newState) {
      state.value = newState;
    });
    return unsubscribe;
  }, [store]);

  return state.value;
}

