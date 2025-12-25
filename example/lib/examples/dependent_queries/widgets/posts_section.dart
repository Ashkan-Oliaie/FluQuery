import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';

/// Section displaying user's posts
class PostsSection extends StatelessWidget {
  final QueryResult<List<Post>, Object> postsQuery;
  final bool userLoaded;

  const PostsSection({
    super.key,
    required this.postsQuery,
    required this.userLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      padding: const EdgeInsets.all(20),
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
                SmallSpinner(color: accentColor, size: 16),
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
                child: SmallSpinner(color: accentColor),
              ),
            )
          else if (postsQuery.isError)
            Text(
              'Error: ${postsQuery.error}',
              style: const TextStyle(color: Colors.red),
            )
          else if (postsQuery.data == null || postsQuery.data!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No posts found',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            )
          else
            ...postsQuery.data!.take(5).map(
                  (post) => _PostItem(post: post),
                ),
        ],
      ),
    );
  }
}

class _PostItem extends StatelessWidget {
  final Post post;

  const _PostItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
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
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
