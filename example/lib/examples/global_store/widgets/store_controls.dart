import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import '../../../api/api_client.dart';

class StoreControls extends HookWidget {
  final QueryStore<AppConfig, Object> store;
  final bool isPaused;
  final VoidCallback onPauseToggle;

  const StoreControls({
    super.key,
    required this.store,
    required this.isPaused,
    required this.onPauseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final isRandomizing = useState(false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.04)
            : Color.lerp(Colors.white, accentColor, 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 35 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store Controls',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ControlButton(
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                label: isPaused ? 'Resume' : 'Pause',
                color: const Color(0xFF22C55E),
                onTap: onPauseToggle,
              ),
              _ControlButton(
                icon: Icons.refresh,
                label: 'Refetch',
                color: const Color(0xFF3B82F6),
                onTap: () => store.refetch(),
              ),
              _ControlButton(
                icon: Icons.shuffle,
                label: 'Randomize',
                color: const Color(0xFF8B5CF6),
                isLoading: isRandomizing.value,
                onTap: () async {
                  isRandomizing.value = true;
                  try {
                    final newConfig = await ApiClient.randomizeConfig();
                    store.setData(newConfig);
                  } finally {
                    isRandomizing.value = false;
                  }
                },
              ),
              _ControlButton(
                icon: Icons.warning_amber,
                label: 'Invalidate',
                color: const Color(0xFFF59E0B),
                onTap: () => store.invalidate(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle : Icons.sync,
                  color: isPaused
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF22C55E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isPaused ? 'Polling paused' : 'Polling every 10 seconds',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
