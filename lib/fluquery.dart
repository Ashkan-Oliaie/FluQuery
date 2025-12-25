/// FluQuery - Powerful asynchronous state management for Flutter
/// 
/// Inspired by TanStack Query (React Query), FluQuery provides:
/// - Automatic caching and cache invalidation
/// - Background refetching
/// - Window focus refetching
/// - Polling/realtime queries
/// - Parallel and dependent queries
/// - Mutations with optimistic updates
/// - Infinite/paginated queries
/// - Offline support
/// - And much more!
/// 
/// Example usage:
/// ```dart
/// // Wrap your app with QueryClientProvider
/// QueryClientProvider(
///   client: QueryClient(),
///   child: MyApp(),
/// );
/// 
/// // Use the useQuery hook in a HookWidget
/// class TodoList extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final todos = useQuery<List<Todo>, Object>(
///       queryKey: ['todos'],
///       queryFn: (_) => fetchTodos(),
///     );
/// 
///     if (todos.isLoading) return CircularProgressIndicator();
///     if (todos.isError) return Text('Error: ${todos.error}');
/// 
///     return ListView(
///       children: todos.data!.map((t) => Text(t.title)).toList(),
///     );
///   }
/// }
/// ```
library;

// Core exports
export 'src/core/types.dart';
export 'src/core/query_key.dart';
export 'src/core/query_state.dart';
export 'src/core/query_options.dart' hide DefaultQueryOptions;
export 'src/core/query.dart';
export 'src/core/query_cache.dart';
export 'src/core/query_observer.dart';
export 'src/core/mutation_state.dart';
export 'src/core/mutation.dart';
export 'src/core/mutation_cache.dart';
export 'src/core/infinite_query.dart';
export 'src/core/query_client.dart';
export 'src/core/logger.dart';

// Widget exports
export 'src/widgets/query_client_provider.dart';
export 'src/widgets/query_builder.dart';

// Hook exports
export 'src/hooks/use_query_client.dart';
export 'src/hooks/use_query.dart';
export 'src/hooks/use_mutation.dart';
export 'src/hooks/use_infinite_query.dart';
export 'src/hooks/use_is_fetching.dart';
export 'src/hooks/use_queries.dart';

// Utility exports
export 'src/utils/focus_manager.dart';
export 'src/utils/connectivity_manager.dart';
