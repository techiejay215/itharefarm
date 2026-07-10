// lib/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
       // lib/widgets/bottom_nav_bar.dart - Fix shadow

boxShadow: const [
  BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, -2),
  ),
],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: const TextStyle(
          fontSize: AppFontSizes.small,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppFontSizes.small,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined),
            activeIcon: Icon(Icons.pets),
            label: 'Animals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop_outlined),
            activeIcon: Icon(Icons.water_drop),
            label: 'Milk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_outlined),
            activeIcon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }
}