import 'package:flutter/foundation.dart';
import 'common/common.dart';
import 'query/query.dart';

// Re-export DefaultQueryOptions for convenience
export 'query/query_options.dart' show DefaultQueryOptions;

/// Configuration for QueryClient
class QueryClientConfig {
  final DefaultQueryOptions defaultOptions;
  final LogLevel logLevel;

  /// Whether to enable FluQuery Devtools.
  ///
  /// When enabled, a floating debug panel will be available in your app
  /// to inspect queries, services, and stores.
  ///
  /// Defaults to `kDebugMode` (true in debug builds, false in release).
  final bool enableDevtools;

  QueryClientConfig({
    DefaultQueryOptions? defaultOptions,
    this.logLevel = LogLevel.warn,
    bool? enableDevtools,
  })  : defaultOptions = defaultOptions ?? DefaultQueryOptions(),
        enableDevtools = enableDevtools ?? kDebugMode;

  QueryClientConfig._default()
      : defaultOptions = DefaultQueryOptions(),
        logLevel = LogLevel.warn,
        enableDevtools = kDebugMode;

  static final QueryClientConfig defaultConfig = QueryClientConfig._default();
}
