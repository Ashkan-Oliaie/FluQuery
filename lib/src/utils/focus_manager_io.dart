// IO (mobile/desktop) stub for focus listener
// These platforms use WidgetsBindingObserver instead

/// Initialize web focus listener (no-op on IO platforms)
Object? initWebFocusListener({
  required void Function() onFocus,
  required void Function() onBlur,
}) {
  // No-op on non-web platforms
  return null;
}

/// Dispose web focus listener (no-op on IO platforms)
void disposeWebFocusListener(Object listener) {
  // No-op on non-web platforms
}

