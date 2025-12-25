import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';
import '../../shared/shared.dart';

/// Card displaying user details
class UserCard extends StatelessWidget {
  final QueryResult<User, Object> userQuery;

  const UserCard({super.key, required this.userQuery});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      padding: const EdgeInsets.all(20),
      child: userQuery.isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SmallSpinner(color: accentColor),
              ),
            )
          : userQuery.isError
              ? Text(
                  'Error: ${userQuery.error}',
                  style: const TextStyle(color: Colors.red),
                )
              : userQuery.data == null
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accentColor, accentColor.withAlpha(180)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              userQuery.data!.name[0],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                                  color:
                                      isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
