// lib/widgets/top_performer_card.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class TopPerformerCard extends StatelessWidget {
  final int rank;
  final String earTag;
  final String breed;
  final double totalMilk;
  final double avgDaily;

  const TopPerformerCard({
    super.key,
    required this.rank,
    required this.earTag,
    required this.breed,
    required this.totalMilk,
    required this.avgDaily,
  });

  String _getRankIcon() {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getRankIcon(),
                style: const TextStyle(
                  fontSize: AppFontSizes.large,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Cow info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cow #$earTag',
                  style: const TextStyle(
                    fontSize: AppFontSizes.medium,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  breed,
                  style: const TextStyle(
                    fontSize: AppFontSizes.small,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          
          // Milk stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalMilk.toStringAsFixed(0)}L',
                style: const TextStyle(
                  fontSize: AppFontSizes.medium,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${avgDaily.toStringAsFixed(0)}L/day',
                style: const TextStyle(
                  fontSize: AppFontSizes.small,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}