import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';

/// All mutations for todo operations
class TodoMutations {
  final UseMutationResult<Subtask, Object, ({int subtaskId, bool completed}), void> toggle;
  final UseMutationResult<Subtask, Object, String, void> create;
  final UseMutationResult<void, Object, int, void> delete;
  final UseMutationResult<void, Object, String, void> priority;

  TodoMutations({
    required this.toggle,
    required this.create,
    required this.delete,
    required this.priority,
  });
}

/// Hook that provides all todo mutations
/// 
/// Updates cache on SUCCESS (not on trigger) - the correct approach:
/// - Server confirms the change
/// - We update our local cache to match
/// - No refetch needed!
TodoMutations useTodoMutations({
  required int todoId,
  required BuildContext context,
}) {
  final client = useQueryClient();

  // Helper to show error
  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Helper to update a subtask in cache
  void updateSubtaskInCache(int subtaskId, Subtask Function(Subtask) updater) {
    // Update in todo-details cache
    final details = client.getQueryData<TodoDetails>(['todo-details', todoId]);
    if (details != null) {
      client.setQueryData(['todo-details', todoId], TodoDetails(
        id: details.id,
        title: details.title,
        completed: details.completed,
        createdAt: details.createdAt,
        subtasks: details.subtasks.map((s) => s.id == subtaskId ? updater(s) : s).toList(),
        activities: details.activities,
        priority: details.priority,
        dueDate: details.dueDate,
        assignee: details.assignee,
        tags: details.tags,
        estimatedHours: details.estimatedHours,
        completedHours: details.completedHours,
      ));
    }

    // Update in subtasks list cache
    final subtasks = client.getQueryData<List<Subtask>>(['subtasks', todoId]);
    if (subtasks != null) {
      client.setQueryData(
        ['subtasks', todoId],
        subtasks.map((s) => s.id == subtaskId ? updater(s) : s).toList(),
      );
    }
  }

  // Helper to add subtask to cache
  void addSubtaskToCache(Subtask subtask) {
    final details = client.getQueryData<TodoDetails>(['todo-details', todoId]);
    if (details != null) {
      client.setQueryData(['todo-details', todoId], TodoDetails(
        id: details.id,
        title: details.title,
        completed: details.completed,
        createdAt: details.createdAt,
        subtasks: [...details.subtasks, subtask],
        activities: details.activities,
        priority: details.priority,
        dueDate: details.dueDate,
        assignee: details.assignee,
        tags: details.tags,
        estimatedHours: details.estimatedHours,
        completedHours: details.completedHours,
      ));
    }

    final subtasks = client.getQueryData<List<Subtask>>(['subtasks', todoId]);
    if (subtasks != null) {
      client.setQueryData(['subtasks', todoId], [...subtasks, subtask]);
    }
  }

  // Helper to remove subtask from cache
  void removeSubtaskFromCache(int subtaskId) {
    final details = client.getQueryData<TodoDetails>(['todo-details', todoId]);
    if (details != null) {
      client.setQueryData(['todo-details', todoId], TodoDetails(
        id: details.id,
        title: details.title,
        completed: details.completed,
        createdAt: details.createdAt,
        subtasks: details.subtasks.where((s) => s.id != subtaskId).toList(),
        activities: details.activities,
        priority: details.priority,
        dueDate: details.dueDate,
        assignee: details.assignee,
        tags: details.tags,
        estimatedHours: details.estimatedHours,
        completedHours: details.completedHours,
      ));
    }

    final subtasks = client.getQueryData<List<Subtask>>(['subtasks', todoId]);
    if (subtasks != null) {
      client.setQueryData(
        ['subtasks', todoId],
        subtasks.where((s) => s.id != subtaskId).toList(),
      );
    }
  }

  // Toggle subtask
  final toggle = useMutation<Subtask, Object, ({int subtaskId, bool completed}), void>(
    mutationFn: (vars) => ApiClient.toggleSubtask(vars.subtaskId, vars.completed),
    onSuccess: (result, vars, _) {
      updateSubtaskInCache(vars.subtaskId, (_) => result);
    },
    onError: (error, _, __) => showError('Failed to toggle: $error'),
  );

  // Create subtask
  final create = useMutation<Subtask, Object, String, void>(
    mutationFn: (title) => ApiClient.createSubtask(todoId, title),
    onSuccess: (newSubtask, _, __) {
      addSubtaskToCache(newSubtask);
    },
    onError: (error, _, __) => showError('Failed to create: $error'),
  );

  // Delete subtask
  final delete = useMutation<void, Object, int, void>(
    mutationFn: (subtaskId) => ApiClient.deleteSubtask(subtaskId),
    onSuccess: (_, subtaskId, __) {
      removeSubtaskFromCache(subtaskId);
    },
    onError: (error, _, __) => showError('Failed to delete: $error'),
  );

  // Change priority
  final priority = useMutation<void, Object, String, void>(
    mutationFn: (priority) => ApiClient.updateTodoPriority(todoId, priority),
    onSuccess: (_, newPriority, __) {
      final details = client.getQueryData<TodoDetails>(['todo-details', todoId]);
      if (details != null) {
        client.setQueryData(['todo-details', todoId], TodoDetails(
          id: details.id,
          title: details.title,
          completed: details.completed,
          createdAt: details.createdAt,
          subtasks: details.subtasks,
          activities: details.activities,
          priority: newPriority,
          dueDate: details.dueDate,
          assignee: details.assignee,
          tags: details.tags,
          estimatedHours: details.estimatedHours,
          completedHours: details.completedHours,
        ));
      }
    },
    onError: (error, _, __) => showError('Failed to update priority: $error'),
  );

  return TodoMutations(
    toggle: toggle,
    create: create,
    delete: delete,
    priority: priority,
  );
}
