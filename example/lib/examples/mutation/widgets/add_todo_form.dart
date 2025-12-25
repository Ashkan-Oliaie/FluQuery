import 'package:flutter/material.dart';
import '../../shared/shared.dart';

class AddTodoForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isPending;
  final Object? error;
  final VoidCallback onSubmit;

  const AddTodoForm({
    super.key,
    required this.controller,
    required this.isPending,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        ThemedCard(
          elevated: true,
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter new todo...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isPending ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: isPending
                    ? const SmallSpinner(color: Colors.white)
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Create failed: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
