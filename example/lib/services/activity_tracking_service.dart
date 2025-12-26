import 'package:fluquery/fluquery.dart';

/// Event representing a tracked user activity.
class ActivityEvent {
  final String id;
  final String category;
  final String action;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const ActivityEvent({
    required this.id,
    required this.category,
    required this.action,
    required this.data,
    required this.timestamp,
  });

  @override
  String toString() => '[$category] $action at ${timestamp.toIso8601String()}';
}

/// Service for tracking user activities throughout the app.
///
/// This service:
/// - Tracks authentication events (login, logout, verification)
/// - Tracks user actions (profile views, settings changes)
/// - Maintains a local log with the last N events
/// - Can sync with backend for analytics
class ActivityTrackingService extends Service {
  final List<ActivityEvent> _localEvents = [];
  int _nextId = 1;

  /// Maximum number of local events to keep
  static const int maxLocalEvents = 100;

  /// Get all tracked events (most recent first)
  List<ActivityEvent> get events => List.unmodifiable(_localEvents);

  /// Get events by category
  List<ActivityEvent> getEventsByCategory(String category) {
    return _localEvents.where((e) => e.category == category).toList();
  }

  /// Get recent events (last N)
  List<ActivityEvent> getRecentEvents([int count = 20]) {
    return _localEvents.take(count).toList();
  }

  /// Track an activity
  void track(String category, String action, [Map<String, dynamic>? data]) {
    final event = ActivityEvent(
      id: 'evt_${_nextId++}',
      category: category,
      action: action,
      data: data ?? {},
      timestamp: DateTime.now(),
    );

    _localEvents.insert(0, event);

    // Trim old events
    if (_localEvents.length > maxLocalEvents) {
      _localEvents.removeRange(maxLocalEvents, _localEvents.length);
    }

    FluQueryLogger.debug('Activity tracked: [$category] $action');
  }

  /// Track authentication events
  void trackAuth(String action, [Map<String, dynamic>? data]) {
    track('auth', action, data);
  }

  /// Track user events
  void trackUser(String action, [Map<String, dynamic>? data]) {
    track('user', action, data);
  }

  /// Track navigation events
  void trackNavigation(String action, [Map<String, dynamic>? data]) {
    track('navigation', action, data);
  }

  /// Clear all tracked events
  void clear() {
    _localEvents.clear();
    FluQueryLogger.debug('Activity tracking: Cleared all events');
  }

  @override
  Future<void> onInit() async {
    track('system', 'service_initialized');
  }

  @override
  Future<void> onReset() async {
    clear();
    track('system', 'service_reset');
  }
}
