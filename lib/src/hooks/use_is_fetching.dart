import 'package:flutter_hooks/flutter_hooks.dart';
import '../core/types.dart';
import '../widgets/query_client_provider.dart';

/// Hook to get the number of queries currently fetching
int useIsFetching({QueryKey? queryKey}) {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  final countState = useState(client.fetchingCount(queryKey: queryKey));

  useEffect(() {
    final subscription = client.queryCache.events.listen((_) {
      countState.value = client.fetchingCount(queryKey: queryKey);
    });

    return subscription.cancel;
  }, [queryKey?.toString()]);

  return countState.value;
}

/// Hook to get the number of mutations currently pending
int useIsMutating() {
  final context = useContext();
  final client = QueryClientProvider.of(context);

  final countState = useState(client.mutatingCount());

  useEffect(() {
    final subscription = client.mutationCache.events.listen((_) {
      countState.value = client.mutatingCount();
    });

    return subscription.cancel;
  }, []);

  return countState.value;
}

