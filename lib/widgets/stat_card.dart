// lib/widgets/stat_card.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
       // lib/widgets/stat_card.dart - Fix shadow

boxShadow: const [
  BoxShadow(
    color: Color(0x0D000000),  // 5% opacity black
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFontSizes.small,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFontSizes.xlarge,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}