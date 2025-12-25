import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../../constants/query_keys.dart';
import '../shared/shared.dart';
import 'widgets/user_selector.dart';
import 'widgets/user_card.dart';
import 'widgets/posts_section.dart';

class DependentQueriesExample extends HookWidget {
  const DependentQueriesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedUserId = useState<int?>(null);

    final userQuery = useQuery<User, Object>(
      queryKey: QueryKeys.userFor(selectedUserId.value ?? 0),
      queryFn: (_) => ApiClient.getUser(selectedUserId.value!),
      enabled: selectedUserId.value != null,
    );

    final postsQuery = useQuery<List<Post>, Object>(
      queryKey: QueryKeys.userPostsFor(selectedUserId.value ?? 0),
      queryFn: (_) => ApiClient.getUserPosts(selectedUserId.value!),
      enabled: selectedUserId.value != null && userQuery.isSuccess,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dependent Queries')),
      body: GradientBackground(
        child: Column(
          children: [
            UserSelector(
              selectedUserId: selectedUserId.value,
              onUserSelected: (id) => selectedUserId.value = id,
            ),
            Expanded(
              child: _buildContent(
                context,
                selectedUserId.value,
                userQuery,
                postsQuery,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    int? selectedId,
    QueryResult<User, Object> userQuery,
    QueryResult<List<Post>, Object> postsQuery,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (selectedId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a user to see their profile',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          UserCard(userQuery: userQuery),
          const SizedBox(height: 16),
          PostsSection(
            postsQuery: postsQuery,
            userLoaded: userQuery.isSuccess,
          ),
        ],
      ),
    );
  }
}
