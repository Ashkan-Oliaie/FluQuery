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
    return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
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
  
  static Future<Todo> updateTodo(int id, {String? title, bool? completed}) async {
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

  // ============ POSTS ============
  static Future<PostsPage> getPosts({int page = 1, int limit = 10}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/posts?page=$page&limit=$limit'),
    );
    
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch posts: ${response.statusCode}');
    }
    
    return PostsPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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
    return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
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
    return data.map((json) => Post.fromJson(json as Map<String, dynamic>)).toList();
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
    return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ============ SERVER TIME ============
  static Future<ServerTime> getServerTime() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/time'),
    );
    
    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch server time: ${response.statusCode}');
    }
    
    return ServerTime.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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

  Todo copyWith({int? id, String? title, bool? completed, DateTime? createdAt}) {
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
      posts: (json['posts'] as List).map((p) => Post.fromJson(p as Map<String, dynamic>)).toList(),
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

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}
