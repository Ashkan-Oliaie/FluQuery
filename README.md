# FluQuery 🚀

**Powerful asynchronous state management for Flutter** - Inspired by [TanStack Query](https://tanstack.com/query)

FluQuery makes fetching, caching, synchronizing, and updating server state in your Flutter applications a breeze. Say goodbye to boilerplate code and complex state management!

[![pub package](https://img.shields.io/pub/v/fluquery.svg)](https://pub.dev/packages/fluquery)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- 🔄 **Automatic Caching** - Data is cached automatically with configurable stale times
- 🔁 **Background Refetching** - Stale data is automatically refreshed in the background
- 📱 **Window Focus Refetching** - Automatically refetch when app comes to foreground (mobile) or tab gains focus (web)
- 🌐 **Network Reconnection Handling** - Refetch when network reconnects
- ⏱️ **Polling/Realtime Updates** - Built-in interval-based refetching
- 📄 **Infinite Queries** - Cursor-based pagination made easy
- ✏️ **Mutations** - Create, update, delete with automatic cache invalidation
- ⚡ **Optimistic Updates** - Instant UI updates with automatic rollback on error
- 🔗 **Dependent Queries** - Sequential queries that depend on each other
- 🔄 **Parallel Queries** - Run multiple queries simultaneously
- 🏎️ **Race Condition Handling** - Automatic cancellation of stale requests
- 🎯 **Retry Logic** - Automatic retries with exponential backoff
- 🧹 **Garbage Collection** - Automatic cleanup of unused cache entries
- 🪝 **Hooks API** - Beautiful Flutter Hooks integration
- 🔍 **Select/Transform** - Transform query data before returning (`useQuerySelect`)
- 📍 **Keep Previous Data** - Smooth transitions between queries with `keepPreviousData`

## 📦 Installation

Add FluQuery to your `pubspec.yaml`:

```yaml
dependencies:
  fluquery: ^1.0.0
  flutter_hooks: ^0.20.5
```

## 🚀 Quick Start

### 1. Setup QueryClientProvider

Wrap your app with `QueryClientProvider`:

```dart
import 'package:fluquery/fluquery.dart';

void main() {
  runApp(
    QueryClientProvider(
      client: QueryClient(),
      child: MyApp(),
    ),
  );
}
```

### 2. Use Queries with Hooks

```dart
class TodoList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final todos = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => fetchTodos(),
    );

    if (todos.isLoading) {
      return CircularProgressIndicator();
    }

    if (todos.isError) {
      return Text('Error: ${todos.error}');
    }

    return ListView(
      children: todos.data!.map((t) => TodoItem(todo: t)).toList(),
    );
  }
}
```

## 📖 Usage

### Basic Query

```dart
final query = useQuery<User, Object>(
  queryKey: ['user', userId],
  queryFn: (_) => fetchUser(userId),
  staleTime: const StaleTime(Duration(minutes: 5)),
);

// Access data
if (query.isSuccess) {
  print(query.data);
}

// Refetch manually
query.refetch();
```

### Query with Options

```dart
final query = useQuery<List<Post>, Object>(
  queryKey: ['posts'],
  queryFn: (_) => fetchPosts(),
  
  // Time after which data is considered stale
  staleTime: const StaleTime(Duration(minutes: 5)),
  
  // Garbage collection time (how long inactive data stays in cache)
  gcTime: const GcTime(Duration(minutes: 10)),
  
  // Polling interval
  refetchInterval: Duration(seconds: 30),
  
  // Retry configuration
  retry: 3,
  retryDelay: (attempt, error) => Duration(seconds: attempt * 2),
  
  // Conditional fetching
  enabled: isLoggedIn,
  
  // Refetch behavior
  refetchOnMount: true,        // Refetch when widget mounts (if stale)
  refetchOnWindowFocus: true,  // Refetch when app/tab gains focus
  refetchOnReconnect: true,    // Refetch when network reconnects
  
  // Initial/placeholder data
  placeholderData: [],
  initialData: cachedPosts,
);
```

### Mutations

```dart
class CreateTodo extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    
    final mutation = useMutation<Todo, Object, String, void>(
      mutationFn: (title) => createTodo(title),
      onSuccess: (data, variables, _) {
        // Invalidate and refetch todos
        client.invalidateQueries(queryKey: ['todos'], refetchType: true);
      },
    );

    return ElevatedButton(
      onPressed: mutation.isPending 
        ? null 
        : () => mutation.mutate('New Todo'),
      child: mutation.isPending 
        ? CircularProgressIndicator()
        : Text('Add Todo'),
    );
  }
}
```

### Optimistic Updates

```dart
final toggleMutation = useMutation<Todo, Object, Todo, List<Todo>>(
  mutationFn: (todo) => updateTodo(todo.id, completed: !todo.completed),
  
  onMutate: (todo) {
    // Cancel outgoing refetches
    client.cancelQueries(queryKey: ['todos']);
    
    // Snapshot previous value
    final previousTodos = client.getQueryData<List<Todo>>(['todos']);
    
    // Optimistically update
    if (previousTodos != null) {
      final newTodos = previousTodos.map((t) {
        return t.id == todo.id ? t.copyWith(completed: !t.completed) : t;
      }).toList();
      client.setQueryData(['todos'], newTodos);
    }
    
    return previousTodos ?? [];
  },
  
  onError: (error, todo, previousTodos) {
    // Rollback on error
    if (previousTodos != null) {
      client.setQueryData(['todos'], previousTodos);
    }
  },
  
  onSettled: (_, __, ___, ____) {
    // Refetch after mutation
    client.invalidateQueries(queryKey: ['todos'], refetchType: true);
  },
);
```

### Race Condition Handling

FluQuery automatically handles race conditions. When a user types quickly in a search field, earlier (slower) requests won't override later (faster) results:

```dart
final searchQuery = useQuery<List<User>, Object>(
  // Query key includes the search term - each unique term is a separate query
  queryKey: ['users', 'search', searchTerm],
  queryFn: (ctx) async {
    // Check for cancellation periodically in long operations
    if (ctx.signal?.isCancelled == true) {
      throw QueryCancelledException();
    }
    
    return await searchUsers(searchTerm);
  },
  enabled: searchTerm.isNotEmpty,
);

// Manually cancel previous queries when search term changes
void onSearchChanged(String newTerm) {
  // Cancel the previous search query
  client.cancelQueries(queryKey: ['users', 'search', previousTerm]);
  previousTerm = newTerm;
}
```

### Infinite Queries

```dart
final postsQuery = useInfiniteQuery<PostsPage, Object, int>(
  queryKey: ['posts'],
  queryFn: (ctx) => fetchPosts(page: ctx.pageParam ?? 1),
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages, lastParam, allParams) {
    return lastPage.hasMore ? lastPage.nextPage : null;
  },
);

// Load more
if (postsQuery.hasNextPage && !postsQuery.isFetchingNextPage) {
  postsQuery.fetchNextPage();
}

// Access all pages
final allPosts = postsQuery.pages.expand((page) => page.posts).toList();
```

### Dependent Queries

```dart
// First query
final userQuery = useQuery<User, Object>(
  queryKey: ['user', userId],
  queryFn: (_) => fetchUser(userId),
);

// Dependent query - only runs when user query succeeds
final postsQuery = useQuery<List<Post>, Object>(
  queryKey: ['user-posts', userId],
  queryFn: (_) => fetchUserPosts(userId),
  enabled: userQuery.isSuccess,  // Only fetch when user is loaded
);
```

### Polling

```dart
final timeQuery = useQuery<ServerTime, Object>(
  queryKey: ['server-time'],
  queryFn: (_) => fetchServerTime(),
  refetchInterval: Duration(seconds: 5),  // Poll every 5 seconds
);
```

### Select (Data Transformation)

Use `useQuerySelect` to transform data before returning. The raw data is still cached, but your component only receives the transformed result:

```dart
// Fetch all users but only return their names
final userNames = useQuerySelect<List<User>, Object, List<String>>(
  queryKey: ['users'],
  queryFn: (_) => fetchUsers(),
  select: (users) => users.map((u) => u.name).toList(),
);

// Result is List<String>, not List<User>!
print(userNames.data); // ['John', 'Jane', 'Bob']

// Compute derived values
final userCount = useQuerySelect<List<User>, Object, int>(
  queryKey: ['users'],
  queryFn: (_) => fetchUsers(),
  select: (users) => users.length,
);

print(userCount.data); // 42
```

### Keep Previous Data

Enable smooth transitions between queries by keeping previous data visible while fetching:

```dart
final userPosts = useQuery<List<Post>, Object>(
  queryKey: ['posts', userId],
  queryFn: (_) => fetchUserPosts(userId),
  keepPreviousData: true,  // Magic!
);

// When userId changes:
// 1. Previous posts stay visible (no loading spinner!)
// 2. New posts are fetched in background
// 3. UI smoothly updates when new data arrives

// Check if showing previous data
if (userPosts.isPreviousData) {
  showBadge('Updating...');
}
```

### Parallel Queries

```dart
final results = useQueries(
  queries: [
    QueryConfig(
      queryKey: ['users'],
      queryFn: (_) => fetchUsers(),
    ),
    QueryConfig(
      queryKey: ['posts'],
      queryFn: (_) => fetchPosts(),
    ),
    QueryConfig(
      queryKey: ['comments'],
      queryFn: (_) => fetchComments(),
    ),
  ],
);

// Access individual results
final usersResult = results[0];
final postsResult = results[1];
final commentsResult = results[2];
```

### QueryBuilder Widget (Alternative to Hooks)

```dart
QueryBuilder<List<Todo>, Object>(
  queryKey: ['todos'],
  queryFn: (_) => fetchTodos(),
  builder: (context, result) {
    if (result.isLoading) return CircularProgressIndicator();
    if (result.isError) return Text('Error: ${result.error}');
    
    return ListView(
      children: result.data!.map((t) => TodoItem(todo: t)).toList(),
    );
  },
)
```

## ⚙️ Configuration

### QueryClient Options

```dart
final client = QueryClient(
  config: QueryClientConfig(
    defaultOptions: DefaultQueryOptions(
      staleTime: StaleTime(Duration(minutes: 5)),
      gcTime: GcTime(Duration(minutes: 10)),
      retry: 3,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      refetchOnMount: true,
    ),
    logLevel: LogLevel.debug,  // Set to LogLevel.warn for production
  ),
);
```

### Query Keys

Query keys are used for caching and deduplication. They can be strings or arrays:

```dart
// Simple key
queryKey: ['todos']

// With variables - each unique combination is a separate cache entry
queryKey: ['todo', todoId]

// Complex keys
queryKey: ['user', userId, 'posts', { 'status': 'active' }]
```

## 🎯 API Reference

### Hooks

| Hook | Description |
|------|-------------|
| `useQuery` | Fetch and cache data |
| `useQuerySelect` | Fetch with data transformation |
| `useMutation` | Create/update/delete operations |
| `useInfiniteQuery` | Paginated/infinite queries |
| `useQueries` | Parallel queries |
| `useQueryClient` | Access the QueryClient |
| `useIsFetching` | Check if any queries are fetching |
| `useIsMutating` | Check if any mutations are pending |
| `useSimpleQuery` | Simplified query hook |

### QueryResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T?` | The resolved data |
| `error` | `E?` | Any error that occurred |
| `isLoading` | `bool` | Initial load in progress |
| `isFetching` | `bool` | Any fetch in progress |
| `isError` | `bool` | Error state |
| `isSuccess` | `bool` | Success state |
| `isRefetching` | `bool` | Background refetch |
| `isStale` | `bool` | Data is stale |
| `isPending` | `bool` | Query hasn't run yet |
| `hasData` | `bool` | Data is available |
| `isPreviousData` | `bool` | Showing previous data (keepPreviousData) |
| `isPlaceholderData` | `bool` | Showing placeholder data |
| `refetch` | `Function` | Manually refetch |
| `dataUpdatedAt` | `DateTime?` | When data was last updated |

### QueryClient Methods

| Method | Description |
|--------|-------------|
| `fetchQuery` | Fetch a query programmatically |
| `prefetchQuery` | Prefetch a query |
| `getQueryData` | Get cached data |
| `setQueryData` | Set cached data directly |
| `invalidateQueries` | Mark queries as stale and optionally refetch |
| `refetchQueries` | Force refetch queries |
| `cancelQueries` | Cancel in-flight queries |
| `removeQueries` | Remove from cache |
| `resetQueries` | Reset to initial state |

### MutationResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T?` | The mutation result |
| `error` | `E?` | Any error that occurred |
| `isPending` | `bool` | Mutation in progress |
| `isError` | `bool` | Error state |
| `isSuccess` | `bool` | Success state |
| `isIdle` | `bool` | Not yet triggered |
| `variables` | `V?` | Current mutation variables |
| `mutate` | `Function` | Trigger the mutation |
| `reset` | `Function` | Reset mutation state |

## 📱 Example App

Check out the [example](./example) directory for a comprehensive demo app showcasing:

- ✅ Basic queries with loading/error states
- ✅ Mutations with cache invalidation  
- ✅ Infinite scroll pagination
- ✅ Dependent/sequential queries
- ✅ Polling/realtime updates
- ✅ Optimistic updates with rollback
- ✅ Race condition handling

### Running the Example

1. **Start the backend server:**
   ```bash
   cd backend
   dart pub get
   dart run bin/server.dart
   ```
   The server runs at `http://localhost:8080`

2. **Run the Flutter app:**
   ```bash
   cd example
   flutter pub get
   flutter run -d chrome  # or any other platform
   ```

## 🗺️ Roadmap

We're continuously improving FluQuery. Here's what's coming:

### 🔥 High Priority

| Feature | Status | Description |
|---------|--------|-------------|
| 💾 **Persister Plugin** | 🔜 Planned | Save/restore cache to disk (Hive, SharedPrefs, SQLite) |
| 🔧 **DevTools** | 🔜 Planned | Debug overlay to inspect cache, queries, and mutations |
| 📊 **Max Cache Size** | 🔜 Planned | Limit cache entries to prevent memory issues |
| 🛡️ **QueryErrorBoundary** | 🔜 Planned | Widget for graceful error handling and recovery |

### ⚡ Medium Priority

| Feature | Status | Description |
|---------|--------|-------------|
| 📴 **Offline Mutation Queue** | 📋 Backlog | Queue mutations when offline, execute on reconnect |
| 📦 **Request Batching** | 📋 Backlog | Combine multiple requests into one |
| 🔄 **Structural Sharing** | 📋 Backlog | Optimize re-renders with deep comparison |
| 🎭 **Suspense-like Boundary** | 📋 Backlog | Loading boundary widget for child queries |

### 🚀 Future

| Feature | Status | Description |
|---------|--------|-------------|
| 🔌 **WebSocket Integration** | 💡 Idea | Real-time updates via WebSocket |
| 📡 **GraphQL Adapter** | 💡 Idea | First-class GraphQL support |
| 🔐 **Auth Token Refresh** | 💡 Idea | Automatic 401 handling with token refresh |
| ⚖️ **Optimistic Locking** | 💡 Idea | Conflict resolution for concurrent updates |

### ✅ Completed Features

- [x] Automatic caching & background refetching
- [x] Window focus & network reconnection handling
- [x] Mutations with cache invalidation
- [x] Infinite/paginated queries
- [x] Optimistic updates with rollback
- [x] Dependent & parallel queries
- [x] Race condition handling with CancellationToken
- [x] Select/Transform data (`useQuerySelect`)
- [x] Keep Previous Data for smooth transitions
- [x] Polling/interval refetching
- [x] Retry with exponential backoff
- [x] Garbage collection

> 💡 Have a feature request? [Open an issue](https://github.com/Ashkan-Oliaie/FluQuery/issues)!

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

## 📄 License

MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [TanStack Query](https://tanstack.com/query) (React Query)
- Built with [flutter_hooks](https://pub.dev/packages/flutter_hooks)

---

Made with ❤️ for the Flutter community
