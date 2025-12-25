import 'package:flutter/material.dart';
import '../../shared/shared.dart';

/// Stats bar showing pagination progress
class PostsStatsBar extends StatelessWidget {
  final int loaded;
  final int total;
  final int pages;
  final bool hasMore;

  const PostsStatsBar({
    super.key,
    required this.loaded,
    required this.total,
    required this.pages,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return ThemedCard(
      margin: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatChip(label: 'Loaded', value: '$loaded', color: accentColor),
          StatChip(
            label: 'Total',
            value: '$total',
            color: Color.lerp(accentColor, Colors.purple, 0.5),
          ),
          StatChip(
            label: 'Pages',
            value: '$pages',
            color: Color.lerp(accentColor, Colors.green, 0.5),
          ),
          StatChip(
            label: 'More',
            value: hasMore ? 'Yes' : 'No',
            color: hasMore
                ? Color.lerp(accentColor, Colors.orange, 0.5)
                : Colors.grey,
          ),
        ],
      ),
    );
  }
}

