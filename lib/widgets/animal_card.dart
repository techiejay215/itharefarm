// lib/widgets/animal_card.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/animal_model.dart';

class AnimalCard extends StatelessWidget {
  final Animal animal;
  final double todayMilk;
  final VoidCallback onTap;

  const AnimalCard({
    super.key,
    required this.animal,
    required this.todayMilk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = animal.getStatusStyle();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cow icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_emotions_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            // Animal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        animal.getDisplayName(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(int.parse(statusStyle['bg']!.substring(1, 7), radix: 16) + 0xFF000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          animal.status,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(int.parse(statusStyle['text']!.substring(1, 7), radix: 16) + 0xFF000000),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${animal.breed} | Tag: #${animal.earTag}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            // Today's milk
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Today's Milk",
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${todayMilk.toStringAsFixed(0)}L',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
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