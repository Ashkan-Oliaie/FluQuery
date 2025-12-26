import 'serializers.dart';

/// Options for query persistence
class PersistOptions<TData> {
  final QueryDataSerializer<TData> serializer;
  final Duration? maxAge;
  final bool persistErrors;
  final String? keyPrefix;

  const PersistOptions({
    required this.serializer,
    this.maxAge,
    this.persistErrors = false,
    this.keyPrefix,
  });
}

