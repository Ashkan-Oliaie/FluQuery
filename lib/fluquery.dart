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
/// - Persistence to disk
/// - And much more!
library;

// Core modules (using barrel exports)
export 'src/core/common/common.dart';
export 'src/core/query/query.dart' hide DefaultQueryOptions;
export 'src/core/mutation/mutation.dart';
export 'src/core/persistence/persistence.dart' hide PersistenceManager;
export 'src/core/service/services.dart';
export 'src/core/query_client.dart';

// Widgets
export 'src/widgets/query_client_provider.dart';
export 'src/widgets/query_builder.dart';
export 'src/widgets/viewmodel_provider.dart';

// Hooks
export 'src/hooks/use_query_client.dart';
export 'src/hooks/use_query.dart';
export 'src/hooks/use_mutation.dart';
export 'src/hooks/use_infinite_query.dart';
export 'src/hooks/use_is_fetching.dart';
export 'src/hooks/use_queries.dart';
export 'src/hooks/use_service.dart';

// Utilities
export 'src/utils/focus_manager.dart';
export 'src/utils/connectivity_manager.dart';

// Devtools
export 'src/devtools/devtools.dart';
