import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/query_client.dart';
import '../widgets/query_client_provider.dart';

/// Hook to get the QueryClient from context
QueryClient useQueryClient() {
  final context = useContext();
  return QueryClientProvider.of(context);
}
