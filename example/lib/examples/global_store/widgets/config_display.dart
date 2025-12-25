import 'package:flutter/material.dart';
import '../../../api/api_client.dart';

class ConfigDisplay extends StatelessWidget {
  final AppConfig config;
  final bool isFetching;

  const ConfigDisplay({
    super.key,
    required this.config,
    required this.isFetching,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.06)
            : Color.lerp(Colors.white, accentColor, 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 20 : 25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Current Config',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isFetching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _ConfigRow(
            label: 'Theme',
            value: config.theme,
            icon: Icons.palette_outlined,
          ),
          _ConfigRow(
            label: 'Accent Color',
            value: config.accentColor,
            icon: Icons.color_lens_outlined,
            trailing: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          _ConfigRow(
            label: 'Font Size',
            value: config.fontSize,
            icon: Icons.text_fields,
          ),
          _ConfigRow(
            label: 'Compact Mode',
            value: config.compactMode ? 'Enabled' : 'Disabled',
            icon: Icons.view_compact_outlined,
          ),
          _ConfigRow(
            label: 'Animations',
            value: config.animationsEnabled ? 'Enabled' : 'Disabled',
            icon: Icons.animation,
          ),
          Divider(
            color: isDark ? const Color(0x33FFFFFF) : Colors.grey.shade200,
            height: 24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Version: ${config.version}',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
              Text(
                'Updated: ${_formatTime(config.updatedAt)}',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  const _ConfigRow({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
