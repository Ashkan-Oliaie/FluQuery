import 'package:flutter/material.dart';
import '../../shared/shared.dart';

/// Horizontal scrolling user selector
class UserSelector extends StatelessWidget {
  final int? selectedUserId;
  final ValueChanged<int> onUserSelected;

  const UserSelector({
    super.key,
    required this.selectedUserId,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a User',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(10, (index) {
                final userId = index + 1;
                final isSelected = selectedUserId == userId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onUserSelected(userId),
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
                                : (isDark ? Colors.white70 : Colors.black54),
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
    );
  }
}

