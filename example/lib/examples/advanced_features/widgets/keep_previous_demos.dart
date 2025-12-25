import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../../constants/query_keys.dart';
import 'result_card.dart';

class WithoutKeepPreviousData extends HookWidget {
  final int userId;

  const WithoutKeepPreviousData({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuery<List<Post>, Object>(
      queryKey: [...QueryKeys.userPostsNoKeep, userId],
      queryFn: (_) => ApiClient.getUserPosts(userId),
      keepPreviousData: false,
    );

    return ResultCard(
      title: '❌ Without keepPreviousData',
      subtitle: query.isFetching ? 'Fetching...' : null,
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      compact: true,
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .take(3)
                  .map((post) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${post.title}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class WithKeepPreviousData extends HookWidget {
  final int userId;

  const WithKeepPreviousData({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuery<List<Post>, Object>(
      queryKey: [...QueryKeys.userPostsWithKeep, userId],
      queryFn: (_) => ApiClient.getUserPosts(userId),
      keepPreviousData: true,
    );

    return ResultCard(
      title: '✅ With keepPreviousData',
      subtitle: query.isPreviousData
          ? '📍 Showing previous data...'
          : query.isFetching
              ? 'Updating...'
              : null,
      isLoading: query.isLoading,
      isFetching: query.isFetching && !query.isPreviousData,
      isPreviousData: query.isPreviousData,
      error: query.error?.toString(),
      compact: true,
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .take(3)
                  .map((post) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${post.title}',
                          style: TextStyle(
                            color: query.isPreviousData
                                ? (isDark ? Colors.white38 : Colors.black26)
                                : (isDark ? Colors.white70 : Colors.black54),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}
