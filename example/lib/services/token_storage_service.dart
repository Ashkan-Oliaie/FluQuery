import 'package:fluquery/fluquery.dart';

/// Service for secure token storage and management.
///
/// In a real app, this would use secure storage (e.g., flutter_secure_storage).
/// For this demo, we use in-memory storage.
class TokenStorageService extends Service {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  /// Current access token
  String? get accessToken => _accessToken;

  /// Current refresh token
  String? get refreshToken => _refreshToken;

  /// Token expiry time
  DateTime? get expiresAt => _expiresAt;

  /// Whether we have a valid token
  bool get hasValidToken {
    if (_accessToken == null || _expiresAt == null) return false;
    return DateTime.now().isBefore(_expiresAt!);
  }

  /// Whether token is about to expire (within 5 minutes)
  bool get isTokenExpiringSoon {
    if (_expiresAt == null) return false;
    return _expiresAt!.difference(DateTime.now()).inMinutes < 5;
  }

  /// Store tokens from auth response
  void storeTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = expiresAt;
    FluQueryLogger.debug('TokenStorageService: Tokens stored');
  }

  /// Clear all stored tokens
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    FluQueryLogger.debug('TokenStorageService: Tokens cleared');
  }

  @override
  Future<void> onInit() async {
    // In a real app, load tokens from secure storage
    FluQueryLogger.debug('TokenStorageService: Initialized');
  }

  @override
  Future<void> onReset() async {
    clearTokens();
  }

  @override
  Future<void> onDispose() async {
    clearTokens();
  }
}
