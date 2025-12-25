import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

class UserList extends StatelessWidget {
  final List<User> users;

  const UserList({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: users.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
                : Color.lerp(Colors.white, accentColor, 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withAlpha(isDark ? 30 : 18)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Color.lerp(
                  accentColor,
                  Colors.primaries[user.id % Colors.primaries.length],
                  0.5,
                ),
                radius: 20,
                child: Text(
                  user.name[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
