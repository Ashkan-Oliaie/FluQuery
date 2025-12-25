import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../api/api_client.dart';
import '../shared/shared.dart';
import 'widgets/posts_stats_bar.dart';
import 'widgets/post_card.dart';

class InfiniteQueryExample extends HookWidget {
  const InfiniteQueryExample({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
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
                ? SmallSpinner(color: accentColor)
                : const Icon(Icons.refresh),
            onPressed: postsQuery.isFetching ? null : () => postsQuery.refetch(),
          ),
        ],
      ),
      body: GradientBackground(
        child: _buildContent(context, postsQuery, scrollController),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UseInfiniteQueryResult<PostsPage, Object, int> query,
    ScrollController scrollController,
  ) {
    final accentColor = Theme.of(context).colorScheme.primary;

    if (query.isLoading) {
      return const LoadingIndicator();
    }

    if (query.isError) {
      return ErrorView(error: query.error, onRetry: () => query.refetch());
    }

    final allPosts = query.pages.expand((page) => page.posts).toList();
    final total = query.pages.isNotEmpty ? query.pages.last.total : 0;

    return Column(
      children: [
        PostsStatsBar(
          loaded: allPosts.length,
          total: total,
          pages: query.pages.length,
          hasMore: query.hasNextPage,
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
                      ? SmallSpinner(color: accentColor)
                      : TextButton(
                          onPressed: () => query.fetchNextPage(),
                          child: Text(
                            'Load More',
                            style: TextStyle(color: accentColor),
                          ),
                        ),
                );
              }
              return PostCard(post: allPosts[index]);
            },
          ),
        ),
      ],
    );
  }
}

