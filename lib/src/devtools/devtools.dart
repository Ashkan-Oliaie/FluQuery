/// FluQuery Devtools - Visual debugging tools for FluQuery
///
/// Wrap your app with [FluQueryDevtools] to enable the devtools panel:
/// ```dart
/// FluQueryDevtools(
///   child: MyApp(),
/// )
/// ```
///
/// Features:
/// - View all cached queries and their states
/// - See stale vs fresh queries at a glance
/// - Manually refetch, invalidate, or reset queries
/// - View retry history and cache timers
/// - Filter and search queries
///
/// Toggle with the floating button or keyboard shortcut (Shift+D).
library;

export 'devtools_controller.dart'
    show DevtoolsController, QuerySnapshot, DevtoolsStats, QueryStatusFilter;
export 'fluquery_devtools.dart';
