import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../api/api_client.dart';

class InfiniteQueryExample extends HookWidget {
  const InfiniteQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();

    // Use FluQuery's useInfiniteQuery hook
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

    // Handle scroll for infinite loading
    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: postsQuery.isFetching ? null : () => postsQuery.refetch(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
          ),
        ),
        child: _buildContent(postsQuery, scrollController),
      ),
    );
  }

  Widget _buildContent(
    UseInfiniteQueryResult<PostsPage, Object, int> query,
    ScrollController scrollController,
  ) {
    if (query.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${query.error}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => query.refetch(),
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
        // Stats
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Loaded', value: '${allPosts.length}', color: Colors.blue),
              _Stat(label: 'Total', value: '$total', color: Colors.purple),
              _Stat(label: 'Pages', value: '${query.pages.length}', color: Colors.green),
              _Stat(
                label: 'More',
                value: query.hasNextPage ? 'Yes' : 'No',
                color: query.hasNextPage ? Colors.orange : Colors.grey,
              ),
            ],
          ),
        ),
        // List
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
                      ? const CircularProgressIndicator()
                      : TextButton(
                          onPressed: () => query.fetchNextPage(),
                          child: const Text('Load More'),
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
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(128))),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${post.id}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text('User ${post.userId}', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(102))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(153)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
