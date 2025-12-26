/// Void callback type
typedef VoidCallback = void Function();

/// Token for cancelling in-flight requests
///
/// Pass this to your query function to support cancellation.
/// When cancelled, any pending operation should abort gracefully.
///
/// Example:
/// ```dart
/// Future<Data> fetchData(QueryFnContext context) async {
///   final response = await http.get(url);
///
///   // Check if cancelled before processing
///   if (context.signal?.isCancelled ?? false) {
///     throw QueryCancelledException();
///   }
///
///   return parseData(response);
/// }
/// ```
class CancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  /// Whether this token has been cancelled
  bool get isCancelled => _isCancelled;

  /// Cancel this token
  ///
  /// Notifies all listeners and prevents future operations.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  /// Add a listener to be called when cancelled
  ///
  /// If already cancelled, the listener is called immediately.
  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  /// Remove a previously added listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// Exception thrown when a query is cancelled
class QueryCancelledException implements Exception {
  final String message;
  const QueryCancelledException([this.message = 'Query was cancelled']);

  @override
  String toString() => 'QueryCancelledException: $message';
}
