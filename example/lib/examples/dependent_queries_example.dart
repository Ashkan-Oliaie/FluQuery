import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class DependentQueriesExample extends HookWidget {
  const DependentQueriesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedUserId = useState<int?>(null);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final userQuery = useQuery<User, Object>(
      queryKey: ['user', selectedUserId.value],
      queryFn: (_) => ApiClient.getUser(selectedUserId.value!),
      enabled: selectedUserId.value != null,
    );

    final postsQuery = useQuery<List<Post>, Object>(
      queryKey: ['user-posts', selectedUserId.value],
      queryFn: (_) => ApiClient.getUserPosts(selectedUserId.value!),
      enabled: selectedUserId.value != null && userQuery.isSuccess,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dependent Queries')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade50, Colors.white],
                ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                    : Color.lerp(Colors.white, accentColor, 0.03),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a User',
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12),
                  ),
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
                                    ? accentColor
                                    : (isDark
                                        ? Colors.white.withAlpha(26)
                                        : Colors.black.withAlpha(13)),
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : (isDark
                                          ? Colors.white.withAlpha(51)
                                          : Colors.black.withAlpha(26)),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$userId',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black54),
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
            Expanded(
                child: _buildContent(
                    context, selectedUserId.value, userQuery, postsQuery)),
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
            Icon(Icons.person_search,
                size: 64, color: isDark ? Colors.white30 : Colors.black26),
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
          _UserCard(userQuery: userQuery),
          const SizedBox(height: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
            : Color.lerp(Colors.white, accentColor, 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
      ),
      child: userQuery.isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: accentColor),
              ),
            )
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              accentColor,
                              accentColor.withAlpha(180)
                            ]),
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
                              Text(
                                userQuery.data!.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userQuery.data!.email,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45),
                              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(isDark ? 35 : 20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Posts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (postsQuery.isFetching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: accentColor),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!userLoaded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Waiting for user data...',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            )
          else if (postsQuery.isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: accentColor),
              ),
            )
          else if (postsQuery.isError)
            Text('Error: ${postsQuery.error}',
                style: const TextStyle(color: Colors.red))
          else if (postsQuery.data == null || postsQuery.data!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('No posts found',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45)),
              ),
            )
          else
            ...postsQuery.data!.take(5).map((post) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(isDark ? 15 : 10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.body,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
