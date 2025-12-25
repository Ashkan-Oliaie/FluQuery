import 'package:flutter/material.dart';

enum RequestStatus {
  pending,
  success,
  cancelled,
  error;

  Color color(Color accentColor) {
    return switch (this) {
      RequestStatus.pending => accentColor,
      RequestStatus.success => Colors.green,
      RequestStatus.cancelled => Colors.orange,
      RequestStatus.error => Colors.red,
    };
  }

  IconData get icon {
    return switch (this) {
      RequestStatus.pending => Icons.hourglass_empty,
      RequestStatus.success => Icons.check_circle,
      RequestStatus.cancelled => Icons.cancel,
      RequestStatus.error => Icons.error,
    };
  }
}

class RequestLog {
  final String query;
  final DateTime startTime;
  final DateTime? endTime;
  final RequestStatus status;

  RequestLog({
    required this.query,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  RequestLog copyWith({DateTime? endTime, RequestStatus? status}) {
    return RequestLog(
      query: query,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }

  Duration? get duration => endTime?.difference(startTime);
}

void updateLog(
  ValueNotifier<List<RequestLog>> history,
  String query,
  DateTime startTime,
  RequestStatus status,
) {
  history.value = history.value.map((log) {
    if (log.query == query && log.startTime == startTime) {
      return log.copyWith(status: status, endTime: DateTime.now());
    }
    return log;
  }).toList();
}
