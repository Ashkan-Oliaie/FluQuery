# FluQuery 🚀

**Powerful asynchronous state management for Flutter** - Inspired by [TanStack Query](https://tanstack.com/query)

[![pub package](https://img.shields.io/pub/v/fluquery.svg)](https://pub.dev/packages/fluquery)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- 🔄 **Automatic Caching** - Data is cached with configurable stale times
- 🔁 **Background Refetching** - Stale data is refreshed automatically
- 📱 **Smart Refetching** - On window focus, network reconnect, or mount
- ⏱️ **Polling** - Built-in interval-based refetching
- 📄 **Infinite Queries** - Cursor-based pagination made easy
- ✏️ **Mutations** - CRUD operations with cache invalidation
- ⚡ **Optimistic Updates** - Instant UI with automatic rollback
- 🏎️ **Race Condition Handling** - Automatic cancellation of stale requests
- 💾 **Persistence** - Save query data to disk
- 🧩 **Services** - Built-in dependency injection with lifecycle management
- 🪝 **Hooks API** - Beautiful Flutter Hooks integration
- 🔍 **Devtools** - Visual debugging tool for inspecting queries and cache

## 📦 Installation

```yaml
dependencies:
  fluquery: ^1.0.0
  flutter_hooks: ^0.20.5
```

## 🚀 Quick Start

### 1. Setup

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

### 2. Use Queries

```dart
class TodoList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final todos = useQuery<List<Todo>, Object>(
      queryKey: ['todos'],
      queryFn: (_) => fetchTodos(),
    );

    if (todos.isLoading) return CircularProgressIndicator();
    if (todos.isError) return Text('Error: ${todos.error}');

    return ListView(
      children: todos.data!.map((t) => TodoItem(todo: t)).toList(),
    );
  }
}
```

### 3. Mutations

```dart
final mutation = useMutation<Todo, Object, String, void>(
  mutationFn: (title) => createTodo(title),
  onSuccess: (data, variables, _) {
    client.invalidateQueries(queryKey: ['todos']);
  },
);

// Trigger
mutation.mutate('New Todo');
```

### 4. Devtools

```dart
QueryClient(
  config: QueryClientConfig(
    enableDevtools: true,
  ),
);
```

## 📖 Core Concepts

### Query Options

```dart
useQuery<List<Post>, Object>(
  queryKey: ['posts'],
  queryFn: (_) => fetchPosts(),
  staleTime: StaleTime(Duration(minutes: 5)),
  cacheTime: CacheTime(Duration(minutes: 10)),
  refetchInterval: Duration(seconds: 30),
  retry: 3,
  enabled: isLoggedIn,
);
```

### Infinite Queries

```dart
final posts = useInfiniteQuery<PostsPage, Object, int>(
  queryKey: ['posts'],
  queryFn: (ctx) => fetchPosts(page: ctx.pageParam ?? 1),
  initialPageParam: 1,
  getNextPageParam: (lastPage, _, __, ___) => 
    lastPage.hasMore ? lastPage.nextPage : null,
);

posts.fetchNextPage(); // Load more
```

### Optimistic Updates

```dart
useMutation<Todo, Object, Todo, List<Todo>>(
  mutationFn: (todo) => updateTodo(todo),
  onMutate: (todo) {
    final previous = client.getQueryData<List<Todo>>(['todos']);
    client.setQueryData(['todos'], [...previous!, todo]);
    return previous;
  },
  onError: (_, __, previous) => client.setQueryData(['todos'], previous),
  onSettled: (_, __, ___, ____) => client.invalidateQueries(queryKey: ['todos']),
);
```

### Persistence

```dart
// Setup
final persister = HiveCePersister();
await persister.init();
final client = QueryClient(persister: persister);
await client.hydrate();

// Use
useQuery<List<Todo>, Object>(
  queryKey: ['todos'],
  queryFn: (_) => fetchTodos(),
  persist: PersistOptions(serializer: TodoListSerializer()),
);
```

## 🧩 Services (Dependency Injection)

FluQuery includes a lightweight service layer for managing dependencies with async lifecycle hooks.

### Define Services

```dart
class AuthService extends Service {
  final TokenStorage _tokens;
  
  AuthService(ServiceRef ref) : _tokens = ref.getSync<TokenStorage>();

  @override
  Future<void> onInit() async {
    await _loadSession();
  }

  @override
  Future<void> onDispose() async {
    await _clearSession();
  }
}
```

### Register & Use

```dart
// Register
await client.initServices((container) {
  container.register<TokenStorage>((ref) => TokenStorage());
  container.register<AuthService>((ref) => AuthService(ref));
});

// In widgets
final auth = useService<AuthService>();

// Or programmatically
final auth = await client.getService<AuthService>();
```

### QueryStore in Services

Services can own `QueryStore` instances that are automatically disposed:

```dart
class UserService extends Service {
  late final QueryStore<User?, Object> userStore;

  UserService(ServiceRef ref) {
    userStore = ref.createStore(
      queryKey: ['current-user'],
      queryFn: (_) => fetchCurrentUser(),
    );
  }
}

// In widgets
final store = useServiceStore<UserService, User?, Object>(
  (service) => service.userStore,
);
```

### Factory & Named Services

```dart
// Factory - new instance each time
container.registerFactory<Logger>((ref) => Logger());
final logger = container.create<Logger>();

// Named - multiple instances of same type
container.registerNamed<ApiClient>('v1', (ref) => ApiClient('api.v1'));
container.registerNamed<ApiClient>('v2', (ref) => ApiClient('api.v2'));
final v1 = await container.get<ApiClient>(name: 'v1');
```

## ⚙️ Configuration

```dart
QueryClient(
  config: QueryClientConfig(
    defaultOptions: DefaultQueryOptions(
      staleTime: StaleTime(Duration(minutes: 5)),
      cacheTime: CacheTime(Duration(minutes: 10)),
      retry: 3,
      refetchOnWindowFocus: true,
    ),
    logLevel: LogLevel.warn,
  ),
);
```

## 🎯 API Reference

### Hooks

| Hook | Description |
|------|-------------|
| `useQuery` | Fetch and cache data |
| `useQuerySelect` | Fetch with data transformation |
| `useMutation` | Create/update/delete operations |
| `useInfiniteQuery` | Paginated queries |
| `useQueries` | Parallel queries |
| `useQueryClient` | Access QueryClient |
| `useService` | Access a service |
| `useServiceStore` | Access a service's QueryStore |

### QueryResult

| Property | Description |
|----------|-------------|
| `data` | The resolved data |
| `error` | Error if any |
| `isLoading` | Initial load |
| `isFetching` | Any fetch in progress |
| `isError` / `isSuccess` | State checks |
| `refetch()` | Manual refetch |

### QueryClient Methods

| Method | Description |
|--------|-------------|
| `fetchQuery` | Fetch programmatically |
| `getQueryData` / `setQueryData` | Direct cache access |
| `invalidateQueries` | Mark stale & refetch |
| `cancelQueries` | Cancel in-flight |
| `getService` | Get a service instance |

## 📱 Example App

```bash
# Start backend
cd backend && dart pub get && dart run bin/server.dart

# Run app
cd example && flutter run
```

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

Made with ❤️ for the Flutter community
