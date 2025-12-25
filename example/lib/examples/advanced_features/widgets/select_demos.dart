import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../../constants/query_keys.dart';
import 'result_card.dart';

class SelectNamesDemo extends HookWidget {
  const SelectNamesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final query = useQuerySelect<List<User>, Object, List<String>>(
      queryKey: QueryKeys.users,
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.map((u) => u.name).toList(),
    );

    return ResultCard(
      title: 'User Names (List<String>)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: accentColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class SelectEmailsDemo extends HookWidget {
  const SelectEmailsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final query = useQuerySelect<List<User>, Object, List<String>>(
      queryKey: QueryKeys.users,
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.map((u) => u.email).toList(),
    );

    return ResultCard(
      title: 'User Emails (List<String>)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: query.data!
                  .map((email) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email,
                              color: Color.lerp(accentColor, Colors.green, 0.5),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              email,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class SelectCountDemo extends HookWidget {
  const SelectCountDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useQuerySelect<List<User>, Object, int>(
      queryKey: QueryKeys.users,
      queryFn: (_) => ApiClient.getUsers(),
      select: (users) => users.length,
    );

    return ResultCard(
      title: 'User Count (int)',
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      error: query.error?.toString(),
      child: query.data != null
          ? Center(
              child: Column(
                children: [
                  Text(
                    '${query.data}',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    'total users',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
