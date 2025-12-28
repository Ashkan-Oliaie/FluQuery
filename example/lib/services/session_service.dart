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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          avatar == other.avatar &&
          role == other.role &&
          mapEquals(preferences, other.preferences);

  @override
  int get hashCode => Object.hash(id, email, name, avatar, role, preferences);
}

/// Session status
enum SessionStatus {
  unknown, // Initial state, checking if we have a session
  unauthenticated, // Not logged in
  pendingVerification, // Login initiated, awaiting verification
  authenticated, // Fully logged in
}

/// Immutable session state
@immutable
class SessionState {
  final User? user;
  final SessionStatus status;
  final String? pendingSessionId;

  const SessionState({
    this.user,
    this.status = SessionStatus.unknown,
    this.pendingSessionId,
  });

  SessionState copyWith({
    User? user,
    SessionStatus? status,
    String? pendingSessionId,
    bool clearUser = false,
    bool clearPendingSessionId = false,
  }) =>
      SessionState(
        user: clearUser ? null : (user ?? this.user),
        status: status ?? this.status,
        pendingSessionId: clearPendingSessionId
            ? null
            : (pendingSessionId ?? this.pendingSessionId),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          user == other.user &&
          status == other.status &&
          pendingSessionId == other.pendingSessionId;

  @override
  int get hashCode => Object.hash(user, status, pendingSessionId);
}

/// Service for managing user session state.
///
/// Uses StatefulService pattern with single immutable state.
///
/// ## Usage in widgets:
/// ```dart
/// class ProfileWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final session = useService<SessionService>();
///
///     // Only rebuilds when user changes
///     final user = useSelector(session, (s) => s.user);
///
///     // Only rebuilds when status changes
///     final status = useSelector(session, (s) => s.status);
///
///     if (status != SessionStatus.authenticated) {
///       return LoginPrompt();
///     }
///     return ProfileCard(user: user!);
///   }
/// }
/// ```
class SessionService extends StatefulService<SessionState> {
  final TokenStorageService _tokenStorage;
  final ActivityTrackingService _activityTracking;

  SessionService(ServiceRef ref)
      : _tokenStorage = ref.getSync<TokenStorageService>(),
        _activityTracking = ref.getSync<ActivityTrackingService>(),
        super(const SessionState());

  // Convenience getters
  SessionStatus get status => state.status;
  User? get currentUser => state.user;
  String? get pendingSessionId => state.pendingSessionId;
  bool get isAuthenticated => state.status == SessionStatus.authenticated;
  bool get isPendingVerification =>
      state.status == SessionStatus.pendingVerification;

  /// Set pending verification state (after login initiated)
  void setPendingVerification(String sessionId) {
    state = state.copyWith(
      status: SessionStatus.pendingVerification,
      pendingSessionId: sessionId,
    );
    _activityTracking.trackAuth('verification_pending', {
      'sessionId': sessionId,
    });
  }

  /// Set authenticated state with user data and tokens
  void setAuthenticated({
    required User userData,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) {
    _tokenStorage.storeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );

    state = state.copyWith(
      user: userData,
      status: SessionStatus.authenticated,
      clearPendingSessionId: true,
    );

    _activityTracking.trackAuth('authenticated', {
      'userId': userData.id,
    });
  }

  /// Clear session (logout)
  void clearSession() {
    final userId = currentUser?.id;
    _tokenStorage.clearTokens();

    state = state.copyWith(
      clearUser: true,
      status: SessionStatus.unauthenticated,
      clearPendingSessionId: true,
    );

    _activityTracking.trackAuth('session_cleared', {
      'userId': userId,
    });
  }

  /// Update current user data
  void updateUser(User userData) {
    state = state.copyWith(user: userData);
    _activityTracking.trackUser('profile_updated', {
      'userId': userData.id,
    });
  }

  /// Check if we have a valid session (on app startup)
  Future<void> checkSession() async {
    if (_tokenStorage.hasValidToken) {
      state = state.copyWith(status: SessionStatus.authenticated);
      _activityTracking.trackAuth('session_restored');
    } else {
      state = state.copyWith(status: SessionStatus.unauthenticated);
    }
  }

  @override
  Future<void> onInit() async {
    await checkSession();
    _activityTracking.track('session', 'service_initialized');
  }

  @override
  Future<void> onReset() async {
    clearSession();
  }
}
