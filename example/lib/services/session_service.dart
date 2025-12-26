import 'package:flutter/foundation.dart';
import 'package:fluquery/fluquery.dart';
import 'token_storage_service.dart';
import 'activity_tracking_service.dart';

/// User model
class User {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String role;
  final Map<String, dynamic> preferences;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    required this.role,
    required this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      role: json['role'] as String,
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar': avatar,
        'role': role,
        'preferences': preferences,
      };

  User copyWith({
    String? name,
    String? avatar,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Session state
enum SessionStatus {
  unknown, // Initial state, checking if we have a session
  unauthenticated, // Not logged in
  pendingVerification, // Login initiated, awaiting verification
  authenticated, // Fully logged in
}

/// Service for managing user session state.
///
/// This service:
/// - Maintains the current user and session status
/// - Uses QueryStore for reactive state
/// - Coordinates with TokenStorageService
/// - Tracks activities via ActivityTrackingService
class SessionService extends Service {
  final TokenStorageService _tokenStorage;
  final ActivityTrackingService _activityTracking;

  late final QueryStore<User?, Object> userStore;
  SessionStatus _status = SessionStatus.unknown;
  final ValueNotifier<SessionStatus> statusNotifier =
      ValueNotifier(SessionStatus.unknown);
  String? _pendingSessionId;

  SessionService(ServiceRef ref)
      : _tokenStorage = ref.get<TokenStorageService>(),
        _activityTracking = ref.get<ActivityTrackingService>() {
    // Create store for user data - will be fetched from API
    userStore = ref.createStore<User?, Object>(
      queryKey: ['session', 'user'],
      queryFn: (_) async => null, // Populated by setUser
    );
  }

  /// Current session status
  SessionStatus get status => _status;

  void _setStatus(SessionStatus status) {
    _status = status;
    if (statusNotifier.value != status) {
      statusNotifier.value = status;
    }
  }

  /// Current user (if authenticated)
  User? get currentUser => userStore.data;

  /// Stream of user state changes
  Stream<QueryState<User?, Object>> get userStream => userStore.stream;

  /// Whether user is authenticated
  bool get isAuthenticated => _status == SessionStatus.authenticated;

  /// Whether verification is pending
  bool get isPendingVerification => _status == SessionStatus.pendingVerification;

  /// The pending session ID (for verification)
  String? get pendingSessionId => _pendingSessionId;

  /// Set pending verification state (after login initiated)
  void setPendingVerification(String sessionId) {
    _setStatus(SessionStatus.pendingVerification);
    _pendingSessionId = sessionId;
    _activityTracking.trackAuth('verification_pending', {
      'sessionId': sessionId,
    });
  }

  /// Set authenticated state with user data and tokens
  void setAuthenticated({
    required User user,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) {
    _tokenStorage.storeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );

    userStore.setData(user);
    _setStatus(SessionStatus.authenticated);
    _pendingSessionId = null;

    _activityTracking.trackAuth('authenticated', {
      'userId': user.id,
    });
  }

  /// Clear session (logout)
  void clearSession() {
    final userId = currentUser?.id;
    _tokenStorage.clearTokens();
    userStore.setData(null);
    _setStatus(SessionStatus.unauthenticated);
    _pendingSessionId = null;

    _activityTracking.trackAuth('session_cleared', {
      'userId': userId,
    });
  }

  /// Update current user data
  void updateUser(User user) {
    userStore.setData(user);
    _activityTracking.trackUser('profile_updated', {
      'userId': user.id,
    });
  }

  /// Check if we have a valid session (on app startup)
  Future<void> checkSession() async {
    if (_tokenStorage.hasValidToken) {
      // We have a token, wait for session validation from API
      _setStatus(SessionStatus.authenticated);
      _activityTracking.trackAuth('session_restored');
    } else {
      _setStatus(SessionStatus.unauthenticated);
    }
  }

  @override
  Future<void> onInit() async {
    await checkSession();
    _activityTracking.track('session', 'service_initialized');
  }

  @override
  Future<void> onDispose() async {
    statusNotifier.dispose();
  }

  @override
  Future<void> onReset() async {
    clearSession();
  }
}

