import 'package:flutter/foundation.dart';
import 'package:fluquery/fluquery.dart';

// ============================================================
// MODELS
// ============================================================

enum TaskFilter { all, active, completed }

enum TaskSort { newest, oldest, alphabetical }

enum TaskPriority { low, medium, high }

class Task {
  final String id;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;
  final TaskPriority priority;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.completed = false,
    required this.createdAt,
    this.priority = TaskPriority.medium,
  });

  Task copyWith(
          {String? title,
          String? description,
          bool? completed,
          TaskPriority? priority}) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        completed: completed ?? this.completed,
        createdAt: createdAt,
        priority: priority ?? this.priority,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          completed == other.completed &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(id, title, description, completed, priority);
}

class TaskEvent {
  final String type;
  final String taskId;
  final DateTime timestamp;
  TaskEvent(this.type, this.taskId) : timestamp = DateTime.now();
}

class UndoAction {
  final String type;
  final Task task;
  final Task? prev;
  UndoAction.create(this.task)
      : type = 'create',
        prev = null;
  UndoAction.delete(this.task)
      : type = 'delete',
        prev = null;
  UndoAction.update(this.task, this.prev) : type = 'update';
}

// ============================================================
// STATE - Single immutable state object
// ============================================================

/// Immutable state for TaskViewModel.
/// All UI state in one place, with proper equality checking.
@immutable
class TaskState {
  final List<Task> tasks;
  final bool isLoading;
  final TaskFilter filter;
  final TaskSort sort;
  final String searchQuery;
  final String? selectedTaskId;

  const TaskState({
    this.tasks = const [],
    this.isLoading = true,
    this.filter = TaskFilter.all,
    this.sort = TaskSort.newest,
    this.searchQuery = '',
    this.selectedTaskId,
  });

  TaskState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    TaskFilter? filter,
    TaskSort? sort,
    String? searchQuery,
    String? selectedTaskId,
    bool clearSelectedTaskId = false,
  }) =>
      TaskState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedTaskId: clearSelectedTaskId
            ? null
            : (selectedTaskId ?? this.selectedTaskId),
      );

  /// Computed: filtered and sorted tasks
  List<Task> get filteredTasks {
    var result = tasks.toList();

    // Apply search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    // Apply filter
    result = switch (filter) {
      TaskFilter.active => result.where((t) => !t.completed).toList(),
      TaskFilter.completed => result.where((t) => t.completed).toList(),
      TaskFilter.all => result,
    };

    // Apply sort
    return switch (sort) {
      TaskSort.newest => result
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      TaskSort.oldest => result
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      TaskSort.alphabetical => result
        ..sort((a, b) => a.title.compareTo(b.title)),
    };
  }

  int get activeCount => tasks.where((t) => !t.completed).length;
  int get completedCount => tasks.where((t) => t.completed).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskState &&
          listEquals(tasks, other.tasks) &&
          isLoading == other.isLoading &&
          filter == other.filter &&
          sort == other.sort &&
          searchQuery == other.searchQuery &&
          selectedTaskId == other.selectedTaskId;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(tasks),
        isLoading,
        filter,
        sort,
        searchQuery,
        selectedTaskId,
      );
}

// ============================================================
// SERVICES - Singleton services for side effects
// ============================================================

/// Tracks analytics events
class AnalyticsService extends Service {
  final events = ReactiveList<TaskEvent>();
  void track(String event, String taskId) =>
      events.add(TaskEvent(event, taskId));
  @override
  Future<void> onDispose() async => events.dispose();
}

/// Stats state
@immutable
class StatsState {
  final int created;
  final int completed;
  final int deleted;

  const StatsState({this.created = 0, this.completed = 0, this.deleted = 0});

  StatsState copyWith({int? created, int? completed, int? deleted}) =>
      StatsState(
        created: created ?? this.created,
        completed: completed ?? this.completed,
        deleted: deleted ?? this.deleted,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsState &&
          created == other.created &&
          completed == other.completed &&
          deleted == other.deleted;

  @override
  int get hashCode => Object.hash(created, completed, deleted);
}

/// Tracks user stats - demonstrates StatefulService
class StatsService extends StatefulService<StatsState> {
  final _start = DateTime.now();

  StatsService() : super(const StatsState());

  Duration get session => DateTime.now().difference(_start);

  void recordCreated() => state = state.copyWith(created: state.created + 1);
  void recordCompleted() =>
      state = state.copyWith(completed: state.completed + 1);
  void recordDeleted() => state = state.copyWith(deleted: state.deleted + 1);
}

/// Manages undo/redo
class UndoService extends Service {
  final undoStack = ReactiveList<UndoAction>();
  final redoStack = ReactiveList<UndoAction>();
  bool get canUndo => undoStack.value.isNotEmpty;
  bool get canRedo => redoStack.value.isNotEmpty;

  void push(UndoAction action) {
    undoStack.add(action);
    redoStack.clear();
    if (undoStack.value.length > 20) {
      undoStack.value = undoStack.value.sublist(undoStack.value.length - 20);
    }
  }

  UndoAction? undo() {
    if (!canUndo) return null;
    final a = undoStack.value.last;
    undoStack.remove(a);
    redoStack.add(a);
    return a;
  }

  UndoAction? redo() {
    if (!canRedo) return null;
    final a = redoStack.value.last;
    redoStack.remove(a);
    undoStack.add(a);
    return a;
  }

  @override
  Future<void> onDispose() async {
    undoStack.dispose();
    redoStack.dispose();
  }
}

// ============================================================
// VIEWMODEL - StatefulService with single state
// ============================================================

/// TaskViewModel demonstrates the StatefulService pattern:
///
/// - **Single state object** - All UI state in one immutable [TaskState]
/// - **Equality checking** - Only notifies when state actually changes
/// - **Selector support** - Widgets subscribe to specific parts of state
/// - **Atomic updates** - Multiple changes = single rebuild
///
/// ## Usage in widgets:
/// ```dart
/// class TaskList extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final vm = ViewModelProvider.of<TaskViewModel>(context);
///
///     // Granular subscription - only rebuilds when tasks change
///     final tasks = useSelector(vm, (s) => s.filteredTasks);
///
///     // Or subscribe to multiple parts
///     final filter = useSelector(vm, (s) => s.filter);
///     final isLoading = useSelector(vm, (s) => s.isLoading);
///
///     return ListView(...);
///   }
/// }
/// ```
class TaskViewModel extends StatefulService<TaskState> {
  final ServiceRef _ref;

  // Injected services
  late final AnalyticsService _analytics;
  late final StatsService _stats;
  late final UndoService _undo;

  TaskViewModel(this._ref) : super(const TaskState());

  @override
  Future<void> onInit() async {
    _analytics = await _ref.get<AnalyticsService>();
    _stats = await _ref.get<StatsService>();
    _undo = await _ref.get<UndoService>();
    await _loadMockData();
  }

  // Expose services for widgets
  AnalyticsService get analytics => _analytics;
  StatsService get stats => _stats;
  UndoService get undo => _undo;

  // Convenience getters
  List<Task> get tasks => state.tasks;
  List<Task> get filteredTasks => state.filteredTasks;
  bool get isLoading => state.isLoading;
  TaskFilter get filter => state.filter;
  TaskSort get sort => state.sort;
  String get searchQuery => state.searchQuery;
  String? get selectedTaskId => state.selectedTaskId;
  int get activeCount => state.activeCount;
  int get completedCount => state.completedCount;

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _loadMockData() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      isLoading: false,
      tasks: [
        Task(
            id: '1',
            title: 'Set up FluQuery',
            completed: true,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            priority: TaskPriority.high),
        Task(
            id: '2',
            title: 'Implement authentication',
            description: 'Add login and session management',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            priority: TaskPriority.high),
        Task(
            id: '3',
            title: 'Create dashboard',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            priority: TaskPriority.medium),
        Task(
            id: '4',
            title: 'Write tests',
            description: 'Cover ViewModels and services',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            priority: TaskPriority.low),
        Task(
            id: '5',
            title: 'Review PR',
            completed: true,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            priority: TaskPriority.medium),
      ],
    );
  }

  void setFilter(TaskFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSort(TaskSort sort) {
    state = state.copyWith(sort: sort);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectTask(String? id) {
    state = state.copyWith(selectedTaskId: id, clearSelectedTaskId: id == null);
  }

  void addTask(String title, String? description, TaskPriority priority) {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      priority: priority,
    );
    state = state.copyWith(tasks: [...state.tasks, task]);
    _analytics.track('task_created', task.id);
    _stats.recordCreated();
    _undo.push(UndoAction.create(task));
  }

  void toggleTask(String id) {
    final idx = state.tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final old = state.tasks[idx];
    final updated = old.copyWith(completed: !old.completed);
    final newTasks = [...state.tasks]..[idx] = updated;

    state = state.copyWith(tasks: newTasks);
    _analytics.track(
        updated.completed ? 'task_completed' : 'task_uncompleted', id);
    if (updated.completed) _stats.recordCompleted();
    _undo.push(UndoAction.update(updated, old));
  }

  void deleteTask(String id) {
    final task = state.tasks.firstWhere((t) => t.id == id);
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
      selectedTaskId: state.selectedTaskId == id ? null : state.selectedTaskId,
      clearSelectedTaskId: state.selectedTaskId == id,
    );
    _analytics.track('task_deleted', id);
    _stats.recordDeleted();
    _undo.push(UndoAction.delete(task));
  }

  void clearCompleted() {
    final completed = state.tasks.where((t) => t.completed).toList();
    state =
        state.copyWith(tasks: state.tasks.where((t) => !t.completed).toList());
    for (final t in completed) {
      _analytics.track('task_cleared', t.id);
      _stats.recordDeleted();
    }
  }

  void undoLast() {
    final action = _undo.undo();
    if (action == null) return;
    switch (action.type) {
      case 'create':
        state = state.copyWith(
            tasks: state.tasks.where((t) => t.id != action.task.id).toList());
        _analytics.track('undo_create', action.task.id);
      case 'delete':
        state = state.copyWith(tasks: [...state.tasks, action.task]);
        _analytics.track('undo_delete', action.task.id);
      case 'update':
        if (action.prev != null) {
          final idx = state.tasks.indexWhere((t) => t.id == action.task.id);
          if (idx != -1) {
            final newTasks = [...state.tasks]..[idx] = action.prev!;
            state = state.copyWith(tasks: newTasks);
          }
          _analytics.track('undo_update', action.task.id);
        }
    }
  }

  void redoLast() {
    final action = _undo.redo();
    if (action == null) return;
    switch (action.type) {
      case 'create':
        state = state.copyWith(tasks: [...state.tasks, action.task]);
        _analytics.track('redo_create', action.task.id);
      case 'delete':
        state = state.copyWith(
            tasks: state.tasks.where((t) => t.id != action.task.id).toList());
        _analytics.track('redo_delete', action.task.id);
      case 'update':
        final idx = state.tasks.indexWhere((t) => t.id == action.task.id);
        if (idx != -1) {
          final newTasks = [...state.tasks]..[idx] = action.task;
          state = state.copyWith(tasks: newTasks);
        }
        _analytics.track('redo_update', action.task.id);
    }
  }

  void refresh() => _loadMockData();
}
