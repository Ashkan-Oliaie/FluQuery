# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-25

### Added
- Initial release of FluQuery
- **Core Features:**
  - `useQuery` hook for data fetching with automatic caching
  - `useQuerySelect` hook for data fetching with transformation
  - `useMutation` hook for create/update/delete operations
  - `useInfiniteQuery` hook for paginated/infinite scroll queries
  - `useQueries` hook for parallel queries
  - `useQueryClient` hook to access the QueryClient
  - `useIsFetching` hook to check fetching state
  - `useIsMutating` hook to check mutation state
  - `useSimpleQuery` hook for simplified queries

- **Caching & Synchronization:**
  - Automatic query caching with configurable stale times
  - Garbage collection for unused cache entries
  - Cache invalidation and refetching
  - Manual cache manipulation via `setQueryData` and `getQueryData`

- **Background Refetching:**
  - Refetch on window/tab focus (web and mobile)
  - Refetch on network reconnection
  - Refetch on widget mount
  - Configurable polling intervals

- **Race Condition Handling:**
  - Automatic cancellation of stale requests
  - Query cancellation via `CancellationToken`
  - `cancelQueries` method for manual cancellation

- **Data Transformation:**
  - `select` function for transforming query data
  - `useQuerySelect` hook for select + query in one

- **Smooth Transitions:**
  - `keepPreviousData` option for smooth UI transitions
  - `isPreviousData` property to detect stale data display

- **Error Handling:**
  - Automatic retry with exponential backoff
  - Configurable retry count and delay
  - Error state management

- **Optimistic Updates:**
  - `onMutate` callback for optimistic updates
  - `onError` callback for rollback
  - `onSettled` callback for cleanup
  - `onSuccess` callback for cache updates

- **Widgets:**
  - `QueryClientProvider` for dependency injection
  - `QueryBuilder` widget as an alternative to hooks

- **Utilities:**
  - `QueryFocusManager` for app lifecycle management
  - `ConnectivityManager` for network state
  - `FluQueryLogger` for debug logging

### Example App
- Basic query example with loading/error states
- Mutation example with CRUD operations
- Infinite query example with pagination
- Dependent queries example
- Polling example with server time
- Optimistic updates example
- Race condition handling example (with 3 demos: Search, Filters, Cancellation)
- Advanced features example (with 3 demos: Select, Keep Previous Data, Comparison)

### Backend
- Dockerized Dart backend for testing
- In-memory database with todos, posts, users, comments
- Configurable artificial delays for race condition demos
