import 'package:flutter/material.dart';

/// An empty state placeholder widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.grey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: displayColor.withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(color: displayColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

