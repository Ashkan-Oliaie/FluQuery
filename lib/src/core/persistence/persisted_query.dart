import '../common/common.dart';

/// A persisted query entry that can be serialized/deserialized
class PersistedQuery {
  final QueryKey queryKey;
  final String queryHash;
  final dynamic serializedData;
  final DateTime? dataUpdatedAt;
  final DateTime persistedAt;
  final String status;

  const PersistedQuery({
    required this.queryKey,
    required this.queryHash,
    required this.serializedData,
    this.dataUpdatedAt,
    required this.persistedAt,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'queryKey': queryKey,
        'queryHash': queryHash,
        'serializedData': serializedData,
        'dataUpdatedAt': dataUpdatedAt?.toIso8601String(),
        'persistedAt': persistedAt.toIso8601String(),
        'status': status,
      };

  factory PersistedQuery.fromJson(Map<String, dynamic> json) {
    return PersistedQuery(
      queryKey: (json['queryKey'] as List).cast<dynamic>(),
      queryHash: json['queryHash'] as String,
      serializedData: json['serializedData'],
      dataUpdatedAt: json['dataUpdatedAt'] != null
          ? DateTime.parse(json['dataUpdatedAt'] as String)
          : null,
      persistedAt: DateTime.parse(json['persistedAt'] as String),
      status: json['status'] as String,
    );
  }
}
