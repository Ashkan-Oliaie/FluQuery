import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class DependentQueriesExample extends HookWidget {
  const DependentQueriesExample({super.key});

  @override
  Widget build(BuildContext context) {
    // State for selected user
    final selectedUserId = useState<int?>(null);

    // First query: Fetch user (only when userId is selected)
    final userQuery = useQuery<User, Object>(
      queryKey: ['user', selectedUserId.value],
      queryFn: (_) => ApiClient.getUser(selectedUserId.value!),
      enabled: selectedUserId.value != null,
    );

    // Dependent query: Fetch user's posts (only when user is loaded)
    final postsQuery = useQuery<List<Post>, Object>(
      queryKey: ['user-posts', selectedUserId.value],
      queryFn: (_) => ApiClient.getUserPosts(selectedUserId.value!),
      enabled: selectedUserId.value != null && userQuery.isSuccess,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dependent Queries')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
          ),
        ),
        child: Column(
          children: [
            // User selector
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a User',
                      style: TextStyle(
                          color: Colors.white.withAlpha(153), fontSize: 12)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(10, (index) {
                        final userId = index + 1;
                        final isSelected = selectedUserId.value == userId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => selectedUserId.value = userId,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : Colors.white.withAlpha(26),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : Colors.white.withAlpha(51),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$userId',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
                child:
                    _buildContent(selectedUserId.value, userQuery, postsQuery)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    int? selectedId,
    QueryResult<User, Object> userQuery,
    QueryResult<List<Post>, Object> postsQuery,
  ) {
    if (selectedId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search,
                size: 64, color: Colors.white.withAlpha(77)),
            const SizedBox(height: 16),
            Text('Select a user to see their profile',
                style: TextStyle(color: Colors.white.withAlpha(128))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // User card
          _UserCard(userQuery: userQuery),
          const SizedBox(height: 16),
          // Posts - dependent on user being loaded
          _PostsSection(
              postsQuery: postsQuery, userLoaded: userQuery.isSuccess),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final QueryResult<User, Object> userQuery;

  const _UserCard({required this.userQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: userQuery.isLoading
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()))
          : userQuery.isError
              ? Text('Error: ${userQuery.error}',
                  style: const TextStyle(color: Colors.red))
              : userQuery.data == null
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                          ),
                          child: Center(
                            child: Text(
                              userQuery.data!.name[0],
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userQuery.data!.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(userQuery.data!.email,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withAlpha(128))),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _PostsSection extends StatelessWidget {
  final QueryResult<List<Post>, Object> postsQuery;
  final bool userLoaded;

  const _PostsSection({required this.postsQuery, required this.userLoaded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              const Text('Posts',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              if (postsQuery.isFetching)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),
          if (!userLoaded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('Waiting for user data...',
                      style: TextStyle(color: Colors.white.withAlpha(128)))),
            )
          else if (postsQuery.isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator()))
          else if (postsQuery.isError)
            Text('Error: ${postsQuery.error}',
                style: const TextStyle(color: Colors.red))
          else if (postsQuery.data == null || postsQuery.data!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('No posts found',
                      style: TextStyle(color: Colors.white.withAlpha(128)))),
            )
          else
            ...postsQuery.data!.take(5).map((post) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(post.body,
                          style: TextStyle(
                              fontSize: 12, color: Colors.white.withAlpha(128)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
