import 'dart:convert';
import 'package:http/http.dart' as http;

/// API configuration
class ApiConfig {
  static String baseUrl = 'http://localhost:8080';

  static void setBaseUrl(String url) {
    baseUrl = url;
  }
}

/// Unified API client for the FluQuery example app
class ApiClient {
  static final http.Client _client = http.Client();

  // ============ TODOS ============
  static Future<List<Todo>> getTodos() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/todos'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch todos: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => Todo.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<Todo> getTodo(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$id'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch todo: ${response.statusCode}');
    }

    return Todo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Todo> createTodo(String title) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/todos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'completed': false}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to create todo: ${response.statusCode}');
    }

    return Todo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Todo> updateTodo(int id,
      {String? title, bool? completed}) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (title != null) 'title': title,
        if (completed != null) 'completed': completed,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update todo: ${response.statusCode}');
    }

    return Todo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteTodo(int id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$id'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete todo: ${response.statusCode}');
    }
  }

  // ============ TODO DETAILS & SUBTASKS ============
  static Future<TodoDetails> getTodoDetails(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$id/details'),
    );

    if (response.statusCode != 200) {
      throw ApiException(
          'Failed to fetch todo details: ${response.statusCode}');
    }

    return TodoDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<Subtask>> getSubtasks(int todoId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$todoId/subtasks'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch subtasks: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => Subtask.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<Subtask> createSubtask(int todoId, String title) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$todoId/subtasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to create subtask: ${response.statusCode}');
    }

    return Subtask.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Subtask> toggleSubtask(int subtaskId, bool completed) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/subtasks/$subtaskId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'completed': completed}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to toggle subtask: ${response.statusCode}');
    }

    return Subtask.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteSubtask(int subtaskId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/subtasks/$subtaskId'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete subtask: ${response.statusCode}');
    }
  }

  static Future<List<Activity>> getTodoActivities(int todoId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$todoId/activities'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch activities: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => Activity.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateTodoPriority(int todoId, String priority) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/todos/$todoId/priority'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'priority': priority}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update priority: ${response.statusCode}');
    }
  }

  // ============ POSTS ============
  static Future<PostsPage> getPosts({int page = 1, int limit = 10}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/posts?page=$page&limit=$limit'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch posts: ${response.statusCode}');
    }

    return PostsPage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Post> getPost(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$id'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch post: ${response.statusCode}');
    }

    return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============ USERS ============
  static Future<List<User>> getUsers() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch users: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<User> getUser(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch user: ${response.statusCode}');
    }

    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<Post>> getUserPosts(int userId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/posts'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch user posts: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => Post.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search users by name or email
  static Future<List<User>> searchUsers(String query) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/search?q=$query'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to search users: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ============ SERVER TIME ============
  static Future<ServerTime> getServerTime() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/time'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch server time: ${response.statusCode}');
    }

    return ServerTime.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============ APP CONFIG ============
  static Future<AppConfig> getConfig() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/config'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch config: ${response.statusCode}');
    }

    return AppConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<AppConfig> updateConfig({
    String? theme,
    String? accentColor,
    String? fontSize,
    bool? compactMode,
    bool? animationsEnabled,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (theme != null) 'theme': theme,
        if (accentColor != null) 'accentColor': accentColor,
        if (fontSize != null) 'fontSize': fontSize,
        if (compactMode != null) 'compactMode': compactMode,
        if (animationsEnabled != null) 'animationsEnabled': animationsEnabled,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update config: ${response.statusCode}');
    }

    return AppConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<AppConfig> randomizeConfig() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/config/randomize'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to randomize config: ${response.statusCode}');
    }

    return AppConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}

// ============ MODELS ============

class Todo {
  final int id;
  final String title;
  final bool completed;
  final DateTime? createdAt;

  const Todo({
    required this.id,
    required this.title,
    required this.completed,
    this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAt': createdAt?.toIso8601String(),
      };

  Todo copyWith(
      {int? id, String? title, bool? completed, DateTime? createdAt}) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Todo($id, $title, $completed)';
}

class Post {
  final int id;
  final String title;
  final String body;
  final int userId;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      userId: json['userId'] as int,
    );
  }
}

class PostsPage {
  final List<Post> posts;
  final int page;
  final bool hasMore;
  final int? nextPage;
  final int total;

  const PostsPage({
    required this.posts,
    required this.page,
    required this.hasMore,
    this.nextPage,
    required this.total,
  });

  factory PostsPage.fromJson(Map<String, dynamic> json) {
    return PostsPage(
      posts: (json['posts'] as List)
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      hasMore: json['hasMore'] as bool,
      nextPage: json['nextPage'] as int?,
      total: json['total'] as int,
    );
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? avatar;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
    );
  }
}

class ServerTime {
  final DateTime time;
  final String timezone;

  const ServerTime({
    required this.time,
    required this.timezone,
  });

  factory ServerTime.fromJson(Map<String, dynamic> json) {
    return ServerTime(
      time: DateTime.parse(json['time'] as String),
      timezone: json['timezone'] as String,
    );
  }
}

class Subtask {
  final int id;
  final int todoId;
  final String title;
  final bool completed;
  final DateTime? createdAt;

  const Subtask({
    required this.id,
    required this.todoId,
    required this.title,
    required this.completed,
    this.createdAt,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'] as int,
      todoId: json['todoId'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Subtask copyWith({bool? completed}) {
    return Subtask(
      id: id,
      todoId: todoId,
      title: title,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }
}

class Activity {
  final int id;
  final int todoId;
  final String action;
  final String description;
  final DateTime timestamp;

  const Activity({
    required this.id,
    required this.todoId,
    required this.action,
    required this.description,
    required this.timestamp,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,
      todoId: json['todoId'] as int,
      action: json['action'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class TodoDetails {
  final int id;
  final String title;
  final bool completed;
  final DateTime? createdAt;
  final List<Subtask> subtasks;
  final List<Activity> activities;
  final String priority;
  final DateTime? dueDate;
  final User? assignee;
  final List<String> tags;
  final int estimatedHours;
  final int completedHours;

  const TodoDetails({
    required this.id,
    required this.title,
    required this.completed,
    this.createdAt,
    required this.subtasks,
    required this.activities,
    required this.priority,
    this.dueDate,
    this.assignee,
    required this.tags,
    required this.estimatedHours,
    required this.completedHours,
  });

  factory TodoDetails.fromJson(Map<String, dynamic> json) {
    return TodoDetails(
      id: json['id'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      subtasks: (json['subtasks'] as List? ?? [])
          .map((s) => Subtask.fromJson(s as Map<String, dynamic>))
          .toList(),
      activities: (json['activities'] as List? ?? [])
          .map((a) => Activity.fromJson(a as Map<String, dynamic>))
          .toList(),
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      assignee: json['assignee'] != null
          ? User.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List? ?? []).cast<String>(),
      estimatedHours: json['estimatedHours'] as int? ?? 0,
      completedHours: json['completedHours'] as int? ?? 0,
    );
  }

  Todo toTodo() => Todo(
        id: id,
        title: title,
        completed: completed,
        createdAt: createdAt,
      );
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

// ============ APP CONFIG ============
class AppConfig {
  final String theme;
  final String accentColor;
  final String fontSize;
  final bool compactMode;
  final bool animationsEnabled;
  final int version;
  final DateTime updatedAt;

  const AppConfig({
    required this.theme,
    required this.accentColor,
    required this.fontSize,
    required this.compactMode,
    required this.animationsEnabled,
    required this.version,
    required this.updatedAt,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      theme: json['theme'] as String? ?? 'dark',
      accentColor: json['accentColor'] as String? ?? 'indigo',
      fontSize: json['fontSize'] as String? ?? 'medium',
      compactMode: json['compactMode'] as bool? ?? false,
      animationsEnabled: json['animationsEnabled'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  AppConfig copyWith({
    String? theme,
    String? accentColor,
    String? fontSize,
    bool? compactMode,
    bool? animationsEnabled,
  }) {
    return AppConfig(
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      fontSize: fontSize ?? this.fontSize,
      compactMode: compactMode ?? this.compactMode,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      version: version,
      updatedAt: updatedAt,
    );
  }
}
