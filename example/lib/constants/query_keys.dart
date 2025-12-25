/// Centralized query keys used throughout the example app.
///
/// Using constants for query keys helps:
/// - Prevent typos
/// - Enable IDE autocompletion
/// - Make refactoring easier
/// - Provide documentation for each query
abstract class QueryKeys {
  // ============ Todos ============

  /// Main todos list query
  static const todos = ['todos'];

  /// Todo details by ID: [...todoDetails, todoId]
  static const todoDetails = ['todo-details'];

  /// Subtasks for a todo: [...subtasks, todoId]
  static const subtasks = ['subtasks'];

  /// Activities for a todo: [...todoActivities, todoId]
  static const todoActivities = ['todo-activities'];

  // ============ Users ============

  /// All users list
  static const users = ['users'];

  /// User search: [...userSearch, searchTerm]
  static const userSearch = ['users', 'search'];

  /// Single user by ID: [...user, userId]
  static const user = ['user'];

  /// Posts for a user: [...userPosts, userId]
  static const userPosts = ['user-posts'];

  // ============ Posts ============

  /// Paginated posts (infinite query)
  static const posts = ['posts'];

  // ============ Server ============

  /// Server time (polling example)
  static const serverTime = ['server-time'];

  // ============ App Config ============

  /// Global app configuration (theme, settings)
  static const appConfig = ['app-config'];

  // ============ Advanced Examples ============

  /// User posts without keepPreviousData: [...userPostsNoKeep, userId]
  static const userPostsNoKeep = ['user-posts-no-keep'];

  /// User posts with keepPreviousData: [...userPostsWithKeep, userId]
  static const userPostsWithKeep = ['user-posts-with-keep'];

  /// Filtered todos: [...todosFiltered, filterType]
  static const todosFiltered = ['todos', 'filtered'];

  /// Slow query for cancellation demo
  static const slowQuery = ['slow-query'];

  // ============ Helper Methods ============

  /// Create a todo details key for a specific todo
  static List<dynamic> todoDetailsFor(int todoId) => [...todoDetails, todoId];

  /// Create a subtasks key for a specific todo
  static List<dynamic> subtasksFor(int todoId) => [...subtasks, todoId];

  /// Create an activities key for a specific todo
  static List<dynamic> activitiesFor(int todoId) => [...todoActivities, todoId];

  /// Create a user key for a specific user
  static List<dynamic> userFor(int userId) => [...user, userId];

  /// Create a user posts key for a specific user
  static List<dynamic> userPostsFor(int userId) => [...userPosts, userId];

  /// Create a search key for a specific term
  static List<dynamic> userSearchFor(String term) => [...userSearch, term];

  /// Create a filtered todos key for a specific filter
  static List<dynamic> todosFilteredFor(String filter) =>
      [...todosFiltered, filter];

  /// Create a slow query key with request ID
  static List<dynamic> slowQueryFor(int requestId) => [...slowQuery, requestId];
}
