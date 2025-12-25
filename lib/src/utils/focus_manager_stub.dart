// Stub file for non-web platforms
// This file provides empty stubs for dart:html types

class Document {
  Stream<dynamic> get onVisibilityChange => const Stream.empty();
  String? get visibilityState => null;
}

class Window {
  Stream<dynamic> get onFocus => const Stream.empty();
  Stream<dynamic> get onBlur => const Stream.empty();
}

final document = Document();
final window = Window();

