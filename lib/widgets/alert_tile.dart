// lib/widgets/alert_tile.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class AlertTile extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const AlertTile({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: AppColors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: AppFontSizes.body,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textLight,
          ),
        ],
      ),
    ),
  );
}
}