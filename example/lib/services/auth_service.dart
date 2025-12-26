import 'dart:convert';
import 'package:fluquery/fluquery.dart';
import 'package:http/http.dart' as http;

import 'token_storage_service.dart';
import 'session_service.dart';
import 'activity_tracking_service.dart';

/// Result of an auth operation
class AuthResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;

  const AuthResult({
    required this.success,
    this.error,
    this.data,
  });

  factory AuthResult.success([Map<String, dynamic>? data]) {
    return AuthResult(success: true, data: data);
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

/// Service for handling authentication operations.
///
/// This service:
/// - Handles login flow (initiate -> verify)
/// - Handles logout
/// - Handles token refresh
/// - Coordinates with SessionService and TokenStorageService
class AuthService extends Service {
  final TokenStorageService _tokenStorage;
  final SessionService _sessionService;
  final ActivityTrackingService _activityTracking;

  static const String _baseUrl = 'http://localhost:8080';

  AuthService(ServiceRef ref)
      : _tokenStorage = ref.get<TokenStorageService>(),
        _sessionService = ref.get<SessionService>(),
        _activityTracking = ref.get<ActivityTrackingService>();

  /// Current session status (delegated to SessionService)
  SessionStatus get status => _sessionService.status;

  /// Current user (delegated to SessionService)
  User? get currentUser => _sessionService.currentUser;

  /// Whether user is authenticated
  bool get isAuthenticated => _sessionService.isAuthenticated;

  /// Whether verification is pending
  bool get isPendingVerification => _sessionService.isPendingVerification;

  /// Initiate login flow
  ///
  /// This sends the login request and puts the session in "pending verification" state.
  Future<AuthResult> login([String email = 'user@example.com']) async {
    _activityTracking.trackAuth('login_started', {'email': email});

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sessionId = data['sessionId'] as String;

        _sessionService.setPendingVerification(sessionId);
        _activityTracking.trackAuth('login_initiated', {
          'sessionId': sessionId,
        });

        return AuthResult.success(data);
      } else {
        final error = jsonDecode(response.body)['error'] as String? ?? 'Login failed';
        _activityTracking.trackAuth('login_failed', {'error': error});
        return AuthResult.failure(error);
      }
    } catch (e) {
      _activityTracking.trackAuth('login_error', {'error': e.toString()});
      return AuthResult.failure('Network error: $e');
    }
  }

  /// Complete verification
  ///
  /// For this demo, any code works. In a real app, the user would enter an OTP.
  Future<AuthResult> verify([String code = '123456']) async {
    final sessionId = _sessionService.pendingSessionId;
    if (sessionId == null) {
      return AuthResult.failure('No pending session');
    }

    _activityTracking.trackAuth('verification_started', {
      'sessionId': sessionId,
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': sessionId,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        _sessionService.setAuthenticated(
          user: User.fromJson(data['user'] as Map<String, dynamic>),
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          expiresAt: DateTime.parse(data['expiresAt'] as String),
        );

        _activityTracking.trackAuth('verification_success', {
          'userId': data['user']['id'],
        });

        return AuthResult.success(data);
      } else {
        final error = jsonDecode(response.body)['error'] as String? ?? 'Verification failed';
        _activityTracking.trackAuth('verification_failed', {'error': error});
        return AuthResult.failure(error);
      }
    } catch (e) {
      _activityTracking.trackAuth('verification_error', {'error': e.toString()});
      return AuthResult.failure('Network error: $e');
    }
  }

  /// Logout
  Future<AuthResult> logout() async {
    final userId = currentUser?.id;
    _activityTracking.trackAuth('logout_started', {'userId': userId});

    try {
      final token = _tokenStorage.accessToken;
      if (token != null) {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Logout should succeed even if API call fails
      FluQueryLogger.warn('Logout API call failed: $e');
    }

    _sessionService.clearSession();
    _activityTracking.trackAuth('logout_complete', {'userId': userId});

    return AuthResult.success();
  }

  /// Refresh tokens
  Future<AuthResult> refreshTokens() async {
    final refreshToken = _tokenStorage.refreshToken;
    if (refreshToken == null) {
      return AuthResult.failure('No refresh token');
    }

    _activityTracking.trackAuth('token_refresh_started');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        _tokenStorage.storeTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          expiresAt: DateTime.parse(data['expiresAt'] as String),
        );

        _activityTracking.trackAuth('token_refresh_success');
        return AuthResult.success(data);
      } else {
        _activityTracking.trackAuth('token_refresh_failed');
        // Token refresh failed - need to re-login
        _sessionService.clearSession();
        return AuthResult.failure('Session expired');
      }
    } catch (e) {
      _activityTracking.trackAuth('token_refresh_error', {'error': e.toString()});
      return AuthResult.failure('Network error: $e');
    }
  }

  /// Get auth header for API calls
  Map<String, String> get authHeaders {
    final token = _tokenStorage.accessToken;
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<void> onInit() async {
    _activityTracking.track('auth', 'service_initialized');
  }

  @override
  Future<void> onReset() async {
    await logout();
  }
}


