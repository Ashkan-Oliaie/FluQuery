import 'package:flutter/foundation.dart';

enum TaskFilter { all, active, completed }

enum TaskSort { newest, oldest, alphabetical }

enum TaskPriority { low, medium, high }

@immutable
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

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    TaskPriority? priority,
  }) =>
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


