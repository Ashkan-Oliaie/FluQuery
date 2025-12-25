import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final bool isFetching;
  final bool isPreviousData;
  final String? error;
  final Widget? child;
  final bool compact;

  const ResultCard({
    super.key,
    required this.title,
    this.subtitle,
    this.isLoading = false,
    this.isFetching = false,
    this.isPreviousData = false,
    this.error,
    this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPreviousData
              ? Colors.orange.withAlpha(128)
              : accentColor.withAlpha(isDark ? 35 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
              if (isFetching && !isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: isPreviousData
                    ? Colors.orange
                    : (isDark ? Colors.white54 : Colors.black45),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isLoading)
            Center(child: CircularProgressIndicator(color: accentColor))
          else if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red))
          else if (child != null)
            child!
          else
            Text(
              'No data',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black26),
            ),
        ],
      ),
    );
  }
}
