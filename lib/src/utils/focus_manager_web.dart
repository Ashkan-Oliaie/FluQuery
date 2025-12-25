// Web-specific focus listener implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

/// Initialize web focus listener
/// Returns an object that can be used to dispose the listener
Object initWebFocusListener({
  required void Function() onFocus,
  required void Function() onBlur,
}) {
  final subscriptions = <StreamSubscription>[];

  // Listen to visibility changes
  subscriptions.add(
    html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        onFocus();
      } else {
        onBlur();
      }
    }),
  );

  // Listen to window focus/blur
  subscriptions.add(html.window.onFocus.listen((_) => onFocus()));
  subscriptions.add(html.window.onBlur.listen((_) => onBlur()));

  return subscriptions;
}

/// Dispose web focus listener
void disposeWebFocusListener(Object listener) {
  if (listener is List<StreamSubscription>) {
    for (final sub in listener) {
      sub.cancel();
    }
  }
}

