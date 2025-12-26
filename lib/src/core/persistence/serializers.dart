/// Serializer interface for converting data to/from persistable format
abstract class QueryDataSerializer<TData> {
  dynamic serialize(TData data);
  TData deserialize(dynamic json);
}

/// Simple JSON serializer for data that's already JSON-compatible
class JsonSerializer<TData> implements QueryDataSerializer<TData> {
  const JsonSerializer();

  @override
  dynamic serialize(TData data) => data;

  @override
  TData deserialize(dynamic json) {
    final dynamic d = json;
    return d;
  }
}

/// Serializer for List<Map> data (common for API responses)
class ListMapSerializer
    implements QueryDataSerializer<List<Map<String, dynamic>>> {
  const ListMapSerializer();

  @override
  dynamic serialize(List<Map<String, dynamic>> data) => data;

  @override
  List<Map<String, dynamic>> deserialize(dynamic json) {
    return (json as List).cast<Map<String, dynamic>>();
  }
}
