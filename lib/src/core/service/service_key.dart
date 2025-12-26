/// A strongly-typed key for identifying services in the container.
///
/// Replaces magic string concatenation like `'$Type#$name'` with a proper
/// value type that has correct equality and hash code semantics.
class ServiceKey {
  final Type type;
  final String? name;

  const ServiceKey(this.type, [this.name]);

  /// Create a key for a regular (unnamed) service.
  const ServiceKey.typed(this.type) : name = null;

  /// Create a key for a named service.
  const ServiceKey.named(this.type, String this.name);

  bool get isNamed => name != null;

  @override
  int get hashCode => Object.hash(type, name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceKey && other.type == type && other.name == name;

  @override
  String toString() => name != null ? '$type($name)' : type.toString();
}
