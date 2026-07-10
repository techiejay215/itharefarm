// lib/widgets/more_menu_item.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const MoreMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
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
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppFontSizes.medium,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppFontSizes.small,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}