import 'common/common.dart';
import 'query/query.dart';

// Re-export DefaultQueryOptions for convenience
export 'query/query_options.dart' show DefaultQueryOptions;

/// Configuration for QueryClient
class QueryClientConfig {
  final DefaultQueryOptions defaultOptions;
  final LogLevel logLevel;

  QueryClientConfig({
    DefaultQueryOptions? defaultOptions,
    this.logLevel = LogLevel.warn,
  }) : defaultOptions = defaultOptions ?? DefaultQueryOptions();

  QueryClientConfig._default()
      : defaultOptions = DefaultQueryOptions(),
        logLevel = LogLevel.warn;

  static final QueryClientConfig defaultConfig = QueryClientConfig._default();
}
