import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

/// State for global app configuration
@immutable
class ConfigState {
  final AppConfig? config;
  final bool isLoading;
  final bool isPaused;

  const ConfigState({
    this.config,
    this.isLoading = false,
    this.isPaused = false,
  });

  ConfigState copyWith({
    AppConfig? config,
    bool? isLoading,
    bool? isPaused,
    bool clearConfig = false,
  }) =>
      ConfigState(
        config: clearConfig ? null : (config ?? this.config),
        isLoading: isLoading ?? this.isLoading,
        isPaused: isPaused ?? this.isPaused,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigState &&
          config == other.config &&
          isLoading == other.isLoading &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(config, isLoading, isPaused);
}

/// Global config service with polling.
///
/// Usage:
/// ```dart
/// // In widgets - use selector
/// final config = useSelect<ConfigService, ConfigState, AppConfig?>((s) => s.config);
/// final isLoading = useSelect<ConfigService, ConfigState, bool>((s) => s.isLoading);
///
/// // For actions
/// final configService = useService<ConfigService>();
/// configService.refresh();
/// configService.togglePause();
/// ```
class ConfigService extends StatefulService<ConfigState> {
  Timer? _refreshTimer;

  ConfigService() : super(const ConfigState());

  // Convenience getters
  AppConfig? get config => state.config;
  bool get isLoading => state.isLoading;
  bool get isPaused => state.isPaused;

  @override
  Future<void> onInit() async {
    await _fetchConfig();
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!state.isPaused) _fetchConfig();
      },
    );
  }

  Future<void> _fetchConfig() async {
    state = state.copyWith(isLoading: true);
    try {
      final config = await ApiClient.getConfig();
      state = state.copyWith(config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => _fetchConfig();

  void pause() {
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    state = state.copyWith(isPaused: false);
  }

  void togglePause() {
    if (state.isPaused) {
      resume();
    } else {
      pause();
    }
  }

  void setConfig(AppConfig config) {
    state = state.copyWith(config: config);
  }

  @override
  Future<void> onDispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
