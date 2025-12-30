import 'package:flutter/foundation.dart';
import 'package:fluquery/fluquery.dart';

import 'models/models.dart';

/// Service keys for this screen - defined here to avoid circular imports
const kTaskService = 'task-manager';
const kAnalytics = 'task-analytics';
const kStats = 'task-stats';
const kUndo = 'task-undo';

@immutable
class TaskState {
  final List<Task> tasks;
  final List<Task> filteredTasks;
  final bool isLoading;
  final TaskFilter filter;
  final TaskSort sort;
  final String searchQuery;
  final String? selectedTaskId;

  const TaskState({
    this.tasks = const [],
    this.filteredTasks = const [],
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
  }) {
    final newTasks = tasks ?? this.tasks;
    final newFilter = filter ?? this.filter;
    final newSort = sort ?? this.sort;
    final newSearch = searchQuery ?? this.searchQuery;

    final needsRecompute =
        tasks != null || filter != null || sort != null || searchQuery != null;

    return TaskState(
      tasks: newTasks,
      filteredTasks: needsRecompute
          ? _computeFiltered(newTasks, newFilter, newSort, newSearch)
          : filteredTasks,
        isLoading: isLoading ?? this.isLoading,
      filter: newFilter,
      sort: newSort,
      searchQuery: newSearch,
        selectedTaskId:
            clearSelectedTaskId ? null : (selectedTaskId ?? this.selectedTaskId),
      );
  }

  static List<Task> _computeFiltered(
    List<Task> tasks,
    TaskFilter filter,
    TaskSort sort,
    String searchQuery,
  ) {
    var result = tasks.toList();

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    result = switch (filter) {
      TaskFilter.active => result.where((t) => !t.completed).toList(),
      TaskFilter.completed => result.where((t) => t.completed).toList(),
      TaskFilter.all => result,
    };

    return switch (sort) {
      TaskSort.newest => result
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      TaskSort.oldest => result
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      TaskSort.alphabetical => result..sort((a, b) => a.title.compareTo(b.title)),
    };
  }

  int get activeCount => tasks.where((t) => !t.completed).length;
  int get completedCount => tasks.where((t) => t.completed).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskState &&
          listEquals(tasks, other.tasks) &&
          listEquals(filteredTasks, other.filteredTasks) &&
          isLoading == other.isLoading &&
          filter == other.filter &&
          sort == other.sort &&
          searchQuery == other.searchQuery &&
          selectedTaskId == other.selectedTaskId;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(tasks),
        Object.hashAll(filteredTasks),
        isLoading,
        filter,
        sort,
        searchQuery,
        selectedTaskId,
      );
}

class AnalyticsService extends Service {
  final events = ReactiveList<TaskEvent>();

  void track(String event, String taskId) =>
      events.add(TaskEvent(event, taskId));

  @override
  Future<void> onDispose() async => events.dispose();
}

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

class StatsService extends StatefulService<StatsState> {
  final _start = DateTime.now();

  StatsService() : super(const StatsState());

  Duration get session => DateTime.now().difference(_start);

  void recordCreated() => state = state.copyWith(created: state.created + 1);
  void recordCompleted() =>
      state = state.copyWith(completed: state.completed + 1);
  void recordDeleted() => state = state.copyWith(deleted: state.deleted + 1);
}

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

class TaskService extends StatefulService<TaskState> {
  late final AnalyticsService _analytics;
  late final StatsService _stats;
  late final UndoService _undo;

  TaskService() : super(const TaskState());

  @override
  Future<void> onInit() async {
    _analytics = ref.getSync<AnalyticsService>(name: kAnalytics);
    _stats = ref.getSync<StatsService>(name: kStats);
    _undo = ref.getSync<UndoService>(name: kUndo);
    await _loadMockData();
  }

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
          priority: TaskPriority.high,
        ),
        Task(
            id: '2',
            title: 'Implement authentication',
            description: 'Add login and session management',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          priority: TaskPriority.high,
        ),
        Task(
            id: '3',
            title: 'Create dashboard',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          priority: TaskPriority.medium,
        ),
        Task(
            id: '4',
            title: 'Write tests',
            description: 'Cover services and state',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          priority: TaskPriority.low,
        ),
        Task(
            id: '5',
            title: 'Review PR',
            completed: true,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          priority: TaskPriority.medium,
        ),
      ],
    );
  }

  void setFilter(TaskFilter filter) => state = state.copyWith(filter: filter);
  void setSort(TaskSort sort) => state = state.copyWith(sort: sort);
  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void selectTask(String? id) {
    state =
        state.copyWith(selectedTaskId: id, clearSelectedTaskId: id == null);
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
