import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

// In-memory database
final _db = InMemoryDatabase();

void main() async {
  final router = Router();

  // Health check
  router.get('/health', (Request request) {
    return Response.ok(jsonEncode(
        {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}));
  });

  // ============ APP CONFIG (Global Store Demo) ============
  router.get('/api/config', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 300);
    return Response.ok(
      jsonEncode(_db.appConfig),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.put('/api/config', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 200);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Update config fields
    if (data.containsKey('theme')) _db.appConfig['theme'] = data['theme'];
    if (data.containsKey('accentColor')) {
      _db.appConfig['accentColor'] = data['accentColor'];
    }
    if (data.containsKey('fontSize')) {
      _db.appConfig['fontSize'] = data['fontSize'];
    }
    if (data.containsKey('compactMode')) {
      _db.appConfig['compactMode'] = data['compactMode'];
    }
    if (data.containsKey('animationsEnabled')) {
      _db.appConfig['animationsEnabled'] = data['animationsEnabled'];
    }
    _db.appConfig['updatedAt'] = DateTime.now().toIso8601String();
    _db.appConfig['version'] = (_db.appConfig['version'] as int) + 1;

    return Response.ok(
      jsonEncode(_db.appConfig),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Simulate config changes (for demo - call this to trigger a config update)
  router.post('/api/config/randomize', (Request request) async {
    await _simulateDelay(minMs: 50, maxMs: 100);
    final themes = ['dark', 'light', 'system'];
    final colors = ['indigo', 'purple', 'teal', 'orange', 'pink', 'blue'];
    final fontSizes = ['small', 'medium', 'large'];

    _db.appConfig = {
      'theme': themes[Random().nextInt(themes.length)],
      'accentColor': colors[Random().nextInt(colors.length)],
      'fontSize': fontSizes[Random().nextInt(fontSizes.length)],
      'compactMode': Random().nextBool(),
      'animationsEnabled': Random().nextBool(),
      'version': (_db.appConfig['version'] as int) + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    return Response.ok(
      jsonEncode(_db.appConfig),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ============ AUTHENTICATION ============

  // Login - Start authentication flow (returns pending verification)
  router.post('/api/auth/login', (Request request) async {
    await _simulateDelay(minMs: 300, maxMs: 600);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = data['email'] as String? ?? 'user@example.com';

    // Create a pending session that requires verification
    final sessionId = _db.createPendingSession(email);

    // Track activity
    _db.trackActivity('auth', 'login_initiated', {
      'email': email,
      'sessionId': sessionId,
    });

    return Response.ok(
      jsonEncode({
        'status': 'pending_verification',
        'sessionId': sessionId,
        'message': 'Verification code sent. Press "Verify" to complete login.',
        'expiresIn': 300, // 5 minutes
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Verify - Complete authentication with code
  router.post('/api/auth/verify', (Request request) async {
    await _simulateDelay(minMs: 200, maxMs: 400);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final sessionId = data['sessionId'] as String?;
    final code = data['code'] as String? ?? '123456'; // Any code works for demo

    if (sessionId == null) {
      return Response(400,
          body: jsonEncode({'error': 'sessionId required'}),
          headers: {'Content-Type': 'application/json'});
    }

    final session = _db.verifySession(sessionId);
    if (session == null) {
      _db.trackActivity('auth', 'verification_failed', {
        'sessionId': sessionId,
        'reason': 'invalid_session',
      });
      return Response(401,
          body: jsonEncode({'error': 'Invalid or expired session'}),
          headers: {'Content-Type': 'application/json'});
    }

    // Track activity
    _db.trackActivity('auth', 'verification_success', {
      'sessionId': sessionId,
      'userId': session['userId'],
    });

    return Response.ok(
      jsonEncode({
        'status': 'authenticated',
        'accessToken': session['accessToken'],
        'refreshToken': session['refreshToken'],
        'user': session['user'],
        'expiresAt': session['expiresAt'],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Get current session
  router.get('/api/auth/session', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 200);
    final authHeader = request.headers['authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'No token provided'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring(7);
    final session = _db.getSessionByToken(token);

    if (session == null) {
      return Response(401,
          body: jsonEncode({'error': 'Invalid or expired token'}),
          headers: {'Content-Type': 'application/json'});
    }

    _db.trackActivity('auth', 'session_checked', {
      'userId': session['user']['id'],
    });

    return Response.ok(
      jsonEncode({
        'user': session['user'],
        'expiresAt': session['expiresAt'],
        'isValid': true,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Refresh token
  router.post('/api/auth/refresh', (Request request) async {
    await _simulateDelay(minMs: 200, maxMs: 400);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final refreshToken = data['refreshToken'] as String?;

    if (refreshToken == null) {
      return Response(400,
          body: jsonEncode({'error': 'refreshToken required'}),
          headers: {'Content-Type': 'application/json'});
    }

    final newTokens = _db.refreshSession(refreshToken);
    if (newTokens == null) {
      _db.trackActivity('auth', 'refresh_failed', {
        'reason': 'invalid_refresh_token',
      });
      return Response(401,
          body: jsonEncode({'error': 'Invalid refresh token'}),
          headers: {'Content-Type': 'application/json'});
    }

    _db.trackActivity('auth', 'token_refreshed', {
      'userId': newTokens['user']['id'],
    });

    return Response.ok(
      jsonEncode(newTokens),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Logout
  router.post('/api/auth/logout', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 200);
    final authHeader = request.headers['authorization'];

    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7);
      final session = _db.getSessionByToken(token);
      if (session != null) {
        _db.trackActivity('auth', 'logout', {
          'userId': session['user']['id'],
        });
      }
      _db.invalidateToken(token);
    }

    return Response.ok(
      jsonEncode({'status': 'logged_out'}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Get activity log (for tracking service demo)
  router.get('/api/auth/activities', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 200);
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

    return Response.ok(
      jsonEncode({
        'activities': _db.authActivities.take(limit).toList(),
        'total': _db.authActivities.length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ============ USER PROFILE (requires auth) ============

  router.get('/api/user/profile', (Request request) async {
    await _simulateDelay(minMs: 150, maxMs: 300);
    final authHeader = request.headers['authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Authentication required'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring(7);
    final session = _db.getSessionByToken(token);

    if (session == null) {
      return Response(401,
          body: jsonEncode({'error': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'});
    }

    _db.trackActivity('user', 'profile_viewed', {
      'userId': session['user']['id'],
    });

    return Response.ok(
      jsonEncode(session['user']),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.put('/api/user/profile', (Request request) async {
    await _simulateDelay(minMs: 200, maxMs: 400);
    final authHeader = request.headers['authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Authentication required'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring(7);
    final session = _db.getSessionByToken(token);

    if (session == null) {
      return Response(401,
          body: jsonEncode({'error': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'});
    }

    final body = await request.readAsString();
    final updates = jsonDecode(body) as Map<String, dynamic>;

    final updatedUser = _db.updateUserProfile(token, updates);

    _db.trackActivity('user', 'profile_updated', {
      'userId': session['user']['id'],
      'fields': updates.keys.toList(),
    });

    return Response.ok(
      jsonEncode(updatedUser),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ============ TODOS ============
  router.get('/api/todos', (Request request) async {
    await _simulateDelay();
    return Response.ok(
      jsonEncode(_db.todos),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.get('/api/todos/<id>', (Request request, String id) async {
    await _simulateDelay();
    final todo = _db.todos.firstWhere(
      (t) => t['id'] == int.parse(id),
      orElse: () => {},
    );
    if (todo.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Todo not found'}));
    }
    return Response.ok(jsonEncode(todo),
        headers: {'Content-Type': 'application/json'});
  });

  router.post('/api/todos', (Request request) async {
    await _simulateDelay();
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final todo = {
      'id': _db.nextTodoId++,
      'title': data['title'] ?? 'Untitled',
      'completed': data['completed'] ?? false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _db.todos.add(todo);

    return Response.ok(jsonEncode(todo),
        headers: {'Content-Type': 'application/json'});
  });

  router.put('/api/todos/<id>', (Request request, String id) async {
    await _simulateDelay();
    final todoId = int.parse(id);
    final index = _db.todos.indexWhere((t) => t['id'] == todoId);

    if (index == -1) {
      return Response.notFound(jsonEncode({'error': 'Todo not found'}));
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    _db.todos[index] = {
      ..._db.todos[index],
      if (data.containsKey('title')) 'title': data['title'],
      if (data.containsKey('completed')) 'completed': data['completed'],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    return Response.ok(jsonEncode(_db.todos[index]),
        headers: {'Content-Type': 'application/json'});
  });

  router.delete('/api/todos/<id>', (Request request, String id) async {
    await _simulateDelay();
    final todoId = int.parse(id);
    _db.todos.removeWhere((t) => t['id'] == todoId);
    return Response.ok(jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'});
  });

  // ============ TODO DETAILS & SUBTASKS ============
  // Get todo details with extended info
  router.get('/api/todos/<id>/details', (Request request, String id) async {
    await _simulateDelay(minMs: 300, maxMs: 600);
    final todoId = int.parse(id);
    final todo = _db.todos.firstWhere(
      (t) => t['id'] == todoId,
      orElse: () => {},
    );
    if (todo.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Todo not found'}));
    }

    // Get subtasks for this todo
    final subtasks = _db.subtasks.where((s) => s['todoId'] == todoId).toList();
    // Get activity log
    final activities =
        _db.activities.where((a) => a['todoId'] == todoId).toList();

    final details = {
      ...todo,
      'subtasks': subtasks,
      'activities': activities,
      'priority': _db.todoPriorities[todoId] ?? 'medium',
      'dueDate':
          DateTime.now().add(Duration(days: todoId % 7)).toIso8601String(),
      'assignee': _db.users[(todoId - 1) % _db.users.length],
      'tags': ['tag-${todoId % 3}', 'tag-${todoId % 5}'],
      'estimatedHours': (todoId % 8) + 1,
      'completedHours':
          todo['completed'] == true ? (todoId % 8) + 1 : (todoId % 4),
    };

    return Response.ok(jsonEncode(details),
        headers: {'Content-Type': 'application/json'});
  });

  // Get subtasks for a todo
  router.get('/api/todos/<id>/subtasks', (Request request, String id) async {
    await _simulateDelay(minMs: 200, maxMs: 400);
    final todoId = int.parse(id);
    final subtasks = _db.subtasks.where((s) => s['todoId'] == todoId).toList();
    return Response.ok(jsonEncode(subtasks),
        headers: {'Content-Type': 'application/json'});
  });

  // Add subtask
  router.post('/api/todos/<id>/subtasks', (Request request, String id) async {
    await _simulateDelay();
    final todoId = int.parse(id);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final subtask = {
      'id': _db.nextSubtaskId++,
      'todoId': todoId,
      'title': data['title'] ?? 'Untitled subtask',
      'completed': data['completed'] ?? false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _db.subtasks.add(subtask);

    // Add activity
    _db.activities.add({
      'id': _db.nextActivityId++,
      'todoId': todoId,
      'action': 'subtask_added',
      'description': 'Added subtask: ${subtask['title']}',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Response.ok(jsonEncode(subtask),
        headers: {'Content-Type': 'application/json'});
  });

  // Toggle subtask
  router.put('/api/subtasks/<id>', (Request request, String id) async {
    await _simulateDelay();
    final subtaskId = int.parse(id);
    final index = _db.subtasks.indexWhere((s) => s['id'] == subtaskId);

    if (index == -1) {
      return Response.notFound(jsonEncode({'error': 'Subtask not found'}));
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final subtask = _db.subtasks[index];
    _db.subtasks[index] = {
      ...subtask,
      if (data.containsKey('title')) 'title': data['title'],
      if (data.containsKey('completed')) 'completed': data['completed'],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Add activity
    if (data.containsKey('completed')) {
      _db.activities.add({
        'id': _db.nextActivityId++,
        'todoId': subtask['todoId'],
        'action':
            data['completed'] ? 'subtask_completed' : 'subtask_uncompleted',
        'description':
            '${data['completed'] ? 'Completed' : 'Uncompleted'} subtask: ${subtask['title']}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return Response.ok(jsonEncode(_db.subtasks[index]),
        headers: {'Content-Type': 'application/json'});
  });

  // Delete subtask
  router.delete('/api/subtasks/<id>', (Request request, String id) async {
    await _simulateDelay();
    final subtaskId = int.parse(id);
    final subtask =
        _db.subtasks.firstWhere((s) => s['id'] == subtaskId, orElse: () => {});

    if (subtask.isNotEmpty) {
      _db.subtasks.removeWhere((s) => s['id'] == subtaskId);

      // Add activity
      _db.activities.add({
        'id': _db.nextActivityId++,
        'todoId': subtask['todoId'],
        'action': 'subtask_deleted',
        'description': 'Deleted subtask: ${subtask['title']}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return Response.ok(jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'});
  });

  // Get activity log for a todo
  router.get('/api/todos/<id>/activities', (Request request, String id) async {
    await _simulateDelay(minMs: 150, maxMs: 300);
    final todoId = int.parse(id);
    final activities =
        _db.activities.where((a) => a['todoId'] == todoId).toList();
    // Sort by timestamp descending
    activities.sort((a, b) =>
        (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return Response.ok(jsonEncode(activities),
        headers: {'Content-Type': 'application/json'});
  });

  // Update todo priority
  router.put('/api/todos/<id>/priority', (Request request, String id) async {
    await _simulateDelay();
    final todoId = int.parse(id);
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    _db.todoPriorities[todoId] = data['priority'] ?? 'medium';

    // Add activity
    _db.activities.add({
      'id': _db.nextActivityId++,
      'todoId': todoId,
      'action': 'priority_changed',
      'description': 'Priority changed to ${_db.todoPriorities[todoId]}',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Response.ok(jsonEncode({'priority': _db.todoPriorities[todoId]}),
        headers: {'Content-Type': 'application/json'});
  });

  // ============ POSTS (Paginated) ============
  router.get('/api/posts', (Request request) async {
    await _simulateDelay();
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;

    final start = (page - 1) * limit;
    final end = start + limit;
    final hasMore = end < _db.posts.length;

    final posts = _db.posts.sublist(
      start.clamp(0, _db.posts.length),
      end.clamp(0, _db.posts.length),
    );

    return Response.ok(
      jsonEncode({
        'posts': posts,
        'page': page,
        'limit': limit,
        'total': _db.posts.length,
        'hasMore': hasMore,
        'nextPage': hasMore ? page + 1 : null,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.get('/api/posts/<id>', (Request request, String id) async {
    await _simulateDelay();
    final post = _db.posts.firstWhere(
      (p) => p['id'] == int.parse(id),
      orElse: () => {},
    );
    if (post.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Post not found'}));
    }
    return Response.ok(jsonEncode(post),
        headers: {'Content-Type': 'application/json'});
  });

  // ============ USERS ============
  router.get('/api/users', (Request request) async {
    await _simulateDelay();
    return Response.ok(jsonEncode(_db.users),
        headers: {'Content-Type': 'application/json'});
  });

  router.get('/api/users/<id>', (Request request, String id) async {
    await _simulateDelay();
    final user = _db.users.firstWhere(
      (u) => u['id'] == int.parse(id),
      orElse: () => {},
    );
    if (user.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'User not found'}));
    }
    return Response.ok(jsonEncode(user),
        headers: {'Content-Type': 'application/json'});
  });

  router.get('/api/users/<id>/posts', (Request request, String id) async {
    await _simulateDelay();
    final userId = int.parse(id);
    final posts = _db.posts.where((p) => p['userId'] == userId).toList();
    return Response.ok(jsonEncode(posts),
        headers: {'Content-Type': 'application/json'});
  });

  // User search - intentionally slower for shorter queries to demonstrate race conditions
  router.get('/api/users/search', (Request request) async {
    final query = request.url.queryParameters['q']?.toLowerCase() ?? '';

    // Shorter queries take longer (race condition demo)
    // This simulates real-world scenarios where broader searches are slower
    final delayMs = 500 + (10 - query.length.clamp(0, 10)) * 100;
    await Future.delayed(Duration(milliseconds: delayMs));

    if (query.isEmpty) {
      return Response.ok(jsonEncode(_db.users),
          headers: {'Content-Type': 'application/json'});
    }

    final results = _db.users.where((u) {
      final name = (u['name'] as String).toLowerCase();
      final email = (u['email'] as String).toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Response.ok(jsonEncode(results),
        headers: {'Content-Type': 'application/json'});
  });

  // ============ SERVER TIME ============
  router.get('/api/time', (Request request) async {
    await _simulateDelay(minMs: 100, maxMs: 300);
    return Response.ok(
      jsonEncode({
        'time': DateTime.now().toIso8601String(),
        'timezone': 'UTC',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ============ COMMENTS ============
  router.get('/api/posts/<postId>/comments',
      (Request request, String postId) async {
    await _simulateDelay();
    final pid = int.parse(postId);
    final comments = _db.comments.where((c) => c['postId'] == pid).toList();
    return Response.ok(jsonEncode(comments),
        headers: {'Content-Type': 'application/json'});
  });

  router.post('/api/posts/<postId>/comments',
      (Request request, String postId) async {
    await _simulateDelay();
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final comment = {
      'id': _db.nextCommentId++,
      'postId': int.parse(postId),
      'body': data['body'] ?? '',
      'author': data['author'] ?? 'Anonymous',
      'createdAt': DateTime.now().toIso8601String(),
    };
    _db.comments.add(comment);

    return Response.ok(jsonEncode(comment),
        headers: {'Content-Type': 'application/json'});
  });

  // Add CORS and logging middleware
  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);

  print(
      '🚀 FluQuery API Server running on http://${server.address.host}:${server.port}');
  print('📚 Endpoints:');
  print('   GET  /health');
  print('   --- Auth (Services Demo) ---');
  print('   POST /api/auth/login');
  print('   POST /api/auth/verify');
  print('   GET  /api/auth/session');
  print('   POST /api/auth/refresh');
  print('   POST /api/auth/logout');
  print('   GET  /api/auth/activities');
  print('   --- User Profile (requires auth) ---');
  print('   GET  /api/user/profile');
  print('   PUT  /api/user/profile');
  print('   --- Todos ---');
  print('   GET  /api/todos');
  print('   POST /api/todos');
  print('   GET  /api/todos/:id');
  print('   PUT  /api/todos/:id');
  print('   DELETE /api/todos/:id');
  print('   GET  /api/todos/:id/details');
  print('   GET  /api/todos/:id/subtasks');
  print('   POST /api/todos/:id/subtasks');
  print('   GET  /api/todos/:id/activities');
  print('   PUT  /api/todos/:id/priority');
  print('   --- Subtasks ---');
  print('   PUT  /api/subtasks/:id');
  print('   DELETE /api/subtasks/:id');
  print('   --- Posts ---');
  print('   GET  /api/posts?page=1&limit=10');
  print('   GET  /api/posts/:id');
  print('   GET  /api/posts/:id/comments');
  print('   POST /api/posts/:id/comments');
  print('   --- Users ---');
  print('   GET  /api/users');
  print('   GET  /api/users/:id');
  print('   GET  /api/users/:id/posts');
  print('   GET  /api/users/search?q=query');
  print('   --- Config (Global Store Demo) ---');
  print('   GET  /api/config');
  print('   PUT  /api/config');
  print('   POST /api/config/randomize');
  print('   --- Other ---');
  print('   GET  /api/time');
}

Future<void> _simulateDelay({int minMs = 200, int maxMs = 800}) async {
  final delay = minMs + Random().nextInt(maxMs - minMs);
  await Future.delayed(Duration(milliseconds: delay));
}

class InMemoryDatabase {
  int nextTodoId = 21;
  int nextCommentId = 101;
  int nextSubtaskId = 61;
  int nextActivityId = 101;
  int nextAuthActivityId = 1;

  final Map<int, String> todoPriorities = {};

  // ============ AUTHENTICATION DATA ============

  // Pending sessions (awaiting verification)
  final Map<String, Map<String, dynamic>> _pendingSessions = {};

  // Active sessions (authenticated)
  final Map<String, Map<String, dynamic>> _activeSessions = {};

  // Activity tracking for auth/user actions
  final List<Map<String, dynamic>> authActivities = [];

  // Demo user data
  final Map<String, dynamic> _demoUser = {
    'id': 'usr_demo_12345',
    'email': 'user@example.com',
    'name': 'Demo User',
    'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=demo',
    'role': 'user',
    'createdAt': '2024-01-15T10:30:00Z',
    'preferences': {
      'theme': 'dark',
      'notifications': true,
      'language': 'en',
    },
  };

  // Create a pending session (login initiated)
  String createPendingSession(String email) {
    final sessionId =
        'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    _pendingSessions[sessionId] = {
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(Duration(minutes: 5)).toIso8601String(),
    };
    return sessionId;
  }

  // Verify a pending session and create an active session
  Map<String, dynamic>? verifySession(String sessionId) {
    final pending = _pendingSessions.remove(sessionId);
    if (pending == null) return null;

    // Check expiry
    final expiresAt = DateTime.parse(pending['expiresAt']);
    if (DateTime.now().isAfter(expiresAt)) return null;

    // Create tokens
    final accessToken =
        'at_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final refreshToken =
        'rt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final tokenExpiry = DateTime.now().add(Duration(hours: 1));

    final session = {
      'userId': _demoUser['id'],
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': Map<String, dynamic>.from(_demoUser),
      'expiresAt': tokenExpiry.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    _activeSessions[accessToken] = session;
    return session;
  }

  // Get session by access token
  Map<String, dynamic>? getSessionByToken(String token) {
    final session = _activeSessions[token];
    if (session == null) return null;

    // Check expiry
    final expiresAt = DateTime.parse(session['expiresAt']);
    if (DateTime.now().isAfter(expiresAt)) {
      _activeSessions.remove(token);
      return null;
    }

    return session;
  }

  // Refresh session with refresh token
  Map<String, dynamic>? refreshSession(String refreshToken) {
    // Find session with this refresh token
    MapEntry<String, Map<String, dynamic>>? sessionEntry;
    for (final entry in _activeSessions.entries) {
      if (entry.value['refreshToken'] == refreshToken) {
        sessionEntry = entry;
        break;
      }
    }

    if (sessionEntry == null) return null;

    // Remove old session
    _activeSessions.remove(sessionEntry.key);

    // Create new tokens
    final newAccessToken =
        'at_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final newRefreshToken =
        'rt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final tokenExpiry = DateTime.now().add(Duration(hours: 1));

    final newSession = {
      'userId': sessionEntry.value['userId'],
      'accessToken': newAccessToken,
      'refreshToken': newRefreshToken,
      'user': sessionEntry.value['user'],
      'expiresAt': tokenExpiry.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    _activeSessions[newAccessToken] = newSession;
    return newSession;
  }

  // Invalidate a token (logout)
  void invalidateToken(String token) {
    _activeSessions.remove(token);
  }

  // Update user profile
  Map<String, dynamic> updateUserProfile(
      String token, Map<String, dynamic> updates) {
    final session = _activeSessions[token];
    if (session == null) return _demoUser;

    final user = session['user'] as Map<String, dynamic>;
    if (updates.containsKey('name')) user['name'] = updates['name'];
    if (updates.containsKey('avatar')) user['avatar'] = updates['avatar'];
    if (updates.containsKey('preferences')) {
      user['preferences'] = {
        ...user['preferences'] as Map<String, dynamic>,
        ...updates['preferences'] as Map<String, dynamic>,
      };
    }

    return user;
  }

  // Track activity
  void trackActivity(
      String category, String action, Map<String, dynamic> data) {
    authActivities.insert(0, {
      'id': nextAuthActivityId++,
      'category': category,
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 500 activities
    if (authActivities.length > 500) {
      authActivities.removeRange(500, authActivities.length);
    }
  }

  // App config for global store demo
  Map<String, dynamic> appConfig = {
    'theme': 'dark',
    'accentColor': 'indigo',
    'fontSize': 'medium',
    'compactMode': false,
    'animationsEnabled': true,
    'version': 1,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  final List<Map<String, dynamic>> todos = List.generate(
      20,
      (i) => {
            'id': i + 1,
            'title': 'Todo ${i + 1}: ${_todoTitles[i % _todoTitles.length]}',
            'completed': i % 3 == 0,
            'createdAt': DateTime.now()
                .subtract(Duration(days: 20 - i))
                .toIso8601String(),
          });

  // Subtasks for todos
  final List<Map<String, dynamic>> subtasks = List.generate(
      60,
      (i) => {
            'id': i + 1,
            'todoId': (i % 20) + 1,
            'title':
                'Subtask ${i + 1}: ${_subtaskTitles[i % _subtaskTitles.length]}',
            'completed': i % 4 == 0,
            'createdAt': DateTime.now()
                .subtract(Duration(hours: 60 - i))
                .toIso8601String(),
          });

  // Activity log for todos
  final List<Map<String, dynamic>> activities = List.generate(
      100,
      (i) => {
            'id': i + 1,
            'todoId': (i % 20) + 1,
            'action': _activityActions[i % _activityActions.length],
            'description':
                _activityDescriptions[i % _activityDescriptions.length],
            'timestamp': DateTime.now()
                .subtract(Duration(hours: 100 - i))
                .toIso8601String(),
          });

  final List<Map<String, dynamic>> posts = List.generate(
      100,
      (i) => {
            'id': i + 1,
            'title': 'Post ${i + 1}: ${_postTitles[i % _postTitles.length]}',
            'body': _postBodies[i % _postBodies.length],
            'userId': (i % 10) + 1,
            'createdAt': DateTime.now()
                .subtract(Duration(days: 100 - i))
                .toIso8601String(),
          });

  final List<Map<String, dynamic>> users = List.generate(
      10,
      (i) => {
            'id': i + 1,
            'name': _userNames[i],
            'email':
                '${_userNames[i].toLowerCase().replaceAll(' ', '.')}@example.com',
            'avatar': 'https://i.pravatar.cc/150?u=${i + 1}',
            'role': i == 0 ? 'admin' : 'user',
          });

  final List<Map<String, dynamic>> comments = List.generate(
      100,
      (i) => {
            'id': i + 1,
            'postId': (i % 20) + 1,
            'body': _commentBodies[i % _commentBodies.length],
            'author': _userNames[i % _userNames.length],
            'createdAt': DateTime.now()
                .subtract(Duration(hours: 100 - i))
                .toIso8601String(),
          });

  static const _todoTitles = [
    'Complete project setup',
    'Review pull requests',
    'Update documentation',
    'Fix critical bug',
    'Deploy to production',
    'Write unit tests',
    'Refactor authentication',
    'Optimize database queries',
    'Design new feature',
    'Team standup meeting',
  ];

  static const _postTitles = [
    'Getting Started with Flutter',
    'Advanced State Management Patterns',
    'Building Beautiful UIs',
    'Async Programming Best Practices',
    'Performance Optimization Tips',
    'Testing Strategies',
    'Clean Architecture Guide',
    'Design Patterns in Dart',
    'REST API Integration',
    'Deployment Strategies',
  ];

  static const _postBodies = [
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
    'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
    'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
    'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
    'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.',
  ];

  static const _userNames = [
    'Alice Johnson',
    'Bob Smith',
    'Charlie Brown',
    'Diana Prince',
    'Edward Norton',
    'Fiona Apple',
    'George Lucas',
    'Hannah Montana',
    'Ivan Drago',
    'Julia Roberts',
  ];

  static const _commentBodies = [
    'Great post! Very informative.',
    'Thanks for sharing this!',
    'I learned something new today.',
    'Could you elaborate on this point?',
    'This helped me solve my problem.',
    'Excellent explanation!',
    'Looking forward to more content like this.',
    'I have a question about the implementation.',
    'Very well written article.',
    'This is exactly what I was looking for.',
  ];

  static const _subtaskTitles = [
    'Research requirements',
    'Create initial draft',
    'Review with team',
    'Implement changes',
    'Write tests',
    'Update documentation',
    'Get approval',
    'Deploy changes',
    'Monitor results',
    'Gather feedback',
  ];

  static const _activityActions = [
    'created',
    'updated',
    'completed',
    'reopened',
    'commented',
    'assigned',
    'priority_changed',
    'due_date_changed',
    'subtask_added',
    'subtask_completed',
  ];

  static const _activityDescriptions = [
    'Task was created',
    'Task details were updated',
    'Task was marked as completed',
    'Task was reopened',
    'A comment was added',
    'Task was assigned to a team member',
    'Priority was changed',
    'Due date was updated',
    'A new subtask was added',
    'A subtask was completed',
  ];
}
