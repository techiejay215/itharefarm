// lib/widgets/activity_tile.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class ActivityTile extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final VoidCallback? onTap;

  const ActivityTile({
    super.key,
    required this.title,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: isCompleted ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppFontSizes.body,
                  color: isCompleted ? AppColors.textLight : AppColors.textDark,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isCompleted)
              const Icon(
                Icons.check,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}