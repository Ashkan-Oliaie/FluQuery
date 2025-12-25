# FluQuery Example App

A comprehensive example app demonstrating all features of the FluQuery package.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.38.5 or higher
- Dart SDK 3.0 or higher
- Docker (optional, for running the backend in a container)

### Running the Backend

The example app requires a backend server to be running. You have two options:

#### Option 1: Run with Dart directly

```bash
cd backend
dart pub get
dart run bin/server.dart
```

#### Option 2: Run with Docker

```bash
cd backend
docker-compose up --build
```

The server will start at `http://localhost:8080`.

#### Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/todos` | GET, POST | List/create todos |
| `/api/todos/:id` | GET, PUT, DELETE | CRUD single todo |
| `/api/posts` | GET | Paginated posts (?page=1&limit=10) |
| `/api/posts/:id` | GET | Single post |
| `/api/users` | GET | List users |
| `/api/users/:id` | GET | Single user |
| `/api/users/:id/posts` | GET | User's posts |
| `/api/users/search` | GET | Search users (?q=query) |
| `/api/time` | GET | Server time (for polling demo) |

### Running the Flutter App

```bash
cd example
flutter pub get
flutter run -d chrome  # or -d macos, -d ios, -d android
```

## 📱 Examples

### 1. Basic Query
Demonstrates the fundamental `useQuery` hook with:
- Loading and error states
- Automatic caching
- Manual refetch
- Cache invalidation
- Stale time configuration

### 2. Mutations
Shows how to perform data mutations with:
- Create, update, and delete operations
- Per-item loading states
- Automatic cache invalidation after mutation
- Error handling

### 3. Infinite Queries
Implements infinite scroll pagination:
- Load more functionality
- Automatic page tracking
- Fetching next page indicator
- Pull-to-refresh

### 4. Dependent Queries
Demonstrates sequential queries:
- First query fetches user data
- Second query depends on user ID
- Enabled/disabled state management

### 5. Polling
Real-time updates with polling:
- Configurable refetch interval
- Start/stop polling controls
- Live server time display

### 6. Optimistic Updates
Instant UI updates with rollback:
- Immediate UI feedback
- Snapshot previous state
- Rollback on error
- Sync with server after mutation

### 7. Race Condition Handling
Automatic handling of concurrent requests:
- **Search Tab**: Search-as-you-type with intentionally slower queries for shorter terms
- **Filters Tab**: Rapid filter switching with keepPreviousData
- **Cancellation Tab**: Manual query cancellation with CancellationToken

### 8. Advanced Features
Select, keepPreviousData, and more:
- **Select Tab**: Transform data before returning (`useQuerySelect`)
- **Keep Previous Tab**: Smooth transitions between queries
- **Comparison Tab**: When to use each feature

## 🔧 Configuration

The example app is configured with debug logging enabled. You can see all FluQuery operations in the console:

```dart
QueryClient(
  config: QueryClientConfig(
    defaultOptions: DefaultQueryOptions(
      staleTime: StaleTime(Duration(minutes: 5)),
      retry: 3,
    ),
    logLevel: LogLevel.debug,  // See all logs
  ),
);
```

## 📁 Project Structure

```
example/
├── lib/
│   ├── api/
│   │   └── api_client.dart      # API client and models
│   ├── examples/
│   │   ├── basic_query_example.dart
│   │   ├── mutation_example.dart
│   │   ├── infinite_query_example.dart
│   │   ├── dependent_queries_example.dart
│   │   ├── polling_example.dart
│   │   ├── optimistic_update_example.dart
│   │   └── race_condition_example.dart
│   └── main.dart                # App entry point
└── pubspec.yaml
```

## 🎨 UI Theme

The example app uses a modern dark theme with gradient backgrounds and glass-morphism effects. Colors are inspired by popular design systems:

- Primary: Indigo (`#6366F1`)
- Success: Green (`#10B981`)
- Warning: Orange (`#F59E0B`)
- Error: Red (`#EF4444`)
- Background: Deep Navy (`#0F0F1A` → `#1A1A2E`)
