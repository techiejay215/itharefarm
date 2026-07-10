// lib/screens/more_screen.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/more_menu_item.dart';
import '../services/role_service.dart';

// Screens
import 'finance_screen.dart';
import 'health_screen.dart';
import 'breeding_screen.dart';
import 'feed_screen.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWorker = RoleService.isWorker();

    // Define menu items with allowed roles
    final List<Map<String, dynamic>> farmManagementItems = [
      {
        'icon': Icons.attach_money,
        'title': 'Finance',
        'subtitle': 'Track income, expenses, and profit',
        'iconColor': Colors.green,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FinanceScreen()),
        ),
        'allowed': !isWorker,
      },
      {
        'icon': Icons.health_and_safety,
        'title': 'Health Records',
        'subtitle': 'Vaccinations, deworming, treatments',
        'iconColor': Colors.red,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HealthScreen()),
        ),
        'allowed': true,
      },
      {
        'icon': Icons.pregnant_woman,
        'title': 'Breeding',
        'subtitle': 'Heat detection, insemination, calving',
        'iconColor': Colors.purple,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BreedingScreen()),
        ),
        'allowed': true,
      },
      {
        'icon': Icons.restaurant,
        'title': 'Feed Management',
        'subtitle': 'Track feed inventory and consumption',
        'iconColor': Colors.orange,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FeedScreen()),
        ),
        'allowed': true,
      },
    ];

    final List<Map<String, dynamic>> salesInventoryItems = [
      {
        'icon': Icons.shopping_cart,
        'title': 'Milk Sales',
        'subtitle': 'Record sales, manage customers, track payments',
        'iconColor': Colors.blue,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesScreen()),
        ),
        'allowed': !isWorker,
      },
      {
        'icon': Icons.inventory,
        'title': 'Inventory',
        'subtitle': 'Medicine, equipment, and supplies stock',
        'iconColor': Colors.teal,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InventoryScreen()),
        ),
        'allowed': true,
      },
    ];

    final List<Map<String, dynamic>> appSettingsItems = [
      {
        'icon': Icons.notifications,
        'title': 'Notifications',
        'subtitle': 'Manage alerts and reminders',
        'iconColor': Colors.amber,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NotificationsScreen()),
        ),
        'allowed': true,
      },
      {
        'icon': Icons.settings,
        'title': 'Settings',
        'subtitle': 'Profile, farm details, preferences',
        'iconColor': Colors.grey,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        'allowed': !isWorker,
      },
    ];

    // Filter visible items per section
    final visibleFarm = farmManagementItems.where((e) => e['allowed']).toList();
    final visibleSales = salesInventoryItems.where((e) => e['allowed']).toList();
    final visibleApp = appSettingsItems.where((e) => e['allowed']).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('More - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Farm Management Section
            if (visibleFarm.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FARM MANAGEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              ...visibleFarm.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MoreMenuItem(
                  icon: item['icon'],
                  title: item['title'],
                  subtitle: item['subtitle'],
                  iconColor: item['iconColor'],
                  onTap: item['onTap'],
                ),
              )),
              const SizedBox(height: 24),
            ],

            // Sales & Inventory Section
            if (visibleSales.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SALES & INVENTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              ...visibleSales.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MoreMenuItem(
                  icon: item['icon'],
                  title: item['title'],
                  subtitle: item['subtitle'],
                  iconColor: item['iconColor'],
                  onTap: item['onTap'],
                ),
              )),
              const SizedBox(height: 24),
            ],

            // App Settings Section
            if (visibleApp.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'APP SETTINGS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              ...visibleApp.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MoreMenuItem(
                  icon: item['icon'],
                  title: item['title'],
                  subtitle: item['subtitle'],
                  iconColor: item['iconColor'],
                  onTap: item['onTap'],
                ),
              )),
              const SizedBox(height: 32),
            ],

            // Version info (always visible)
            const Center(
              child: Text(
                'Ithare Farm Dairy Manager v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Licensed to Ithare Farm',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}