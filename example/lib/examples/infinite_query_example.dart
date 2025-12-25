import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class InfiniteQueryExample extends HookWidget {
  const InfiniteQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final postsQuery = useInfiniteQuery<PostsPage, Object, int>(
      queryKey: ['posts'],
      queryFn: (ctx) async {
        final page = (ctx.pageParam as int?) ?? 1;
        return ApiClient.getPosts(page: page, limit: 10);
      },
      getNextPageParam: (lastPage, allPages, lastPageParam, allPageParams) =>
          lastPage.hasMore ? lastPage.nextPage : null,
      initialPageParam: 1,
    );

    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          if (postsQuery.hasNextPage && !postsQuery.isFetchingNextPage) {
            postsQuery.fetchNextPage();
          }
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [postsQuery.hasNextPage, postsQuery.isFetchingNextPage]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite Query'),
        actions: [
          IconButton(
            icon: postsQuery.isFetching && !postsQuery.isFetchingNextPage
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : const Icon(Icons.refresh),
            onPressed:
                postsQuery.isFetching ? null : () => postsQuery.refetch(),
          ),
        ],
      ),
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
        child: _buildContent(context, postsQuery, scrollController),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UseInfiniteQueryResult<PostsPage, Object, int> query,
    ScrollController scrollController,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (query.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${query.error}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => query.refetch(),
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allPosts = query.pages.expand((page) => page.posts).toList();
    final total = query.pages.isNotEmpty ? query.pages.last.total : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                : Color.lerp(Colors.white, accentColor, 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withAlpha(isDark ? 40 : 25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                  label: 'Loaded',
                  value: '${allPosts.length}',
                  color: accentColor),
              _Stat(
                  label: 'Total',
                  value: '$total',
                  color: Color.lerp(accentColor, Colors.purple, 0.5)!),
              _Stat(
                  label: 'Pages',
                  value: '${query.pages.length}',
                  color: Color.lerp(accentColor, Colors.green, 0.5)!),
              _Stat(
                label: 'More',
                value: query.hasNextPage ? 'Yes' : 'No',
                color: query.hasNextPage
                    ? Color.lerp(accentColor, Colors.orange, 0.5)!
                    : Colors.grey,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allPosts.length + (query.hasNextPage ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= allPosts.length) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: query.isFetchingNextPage
                      ? CircularProgressIndicator(color: accentColor)
                      : TextButton(
                          onPressed: () => query.fetchNextPage(),
                          child: Text('Load More',
                              style: TextStyle(color: accentColor)),
                        ),
                );
              }
              return _PostCard(post: allPosts[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${post.id}',
                  style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text(
                'User ${post.userId}',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black26),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
