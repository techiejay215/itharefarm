// lib/screens/reports_screen.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/role_service.dart';  // ✅ Added
import '../widgets/report_card.dart';
import 'milk_report_screen.dart';
import 'animal_report_screen.dart';
import 'health_report_screen.dart';
import 'breeding_report_screen.dart';
import 'sales_report_screen.dart';
import 'financial_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛡️ Role‑based access guard
    if (RoleService.isWorker()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied for your role'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      });
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ReportCard(
              icon: Icons.water_drop,
              title: 'Milk Production Report',
              subtitle: 'View milk production trends and statistics',
              iconColor: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MilkReportScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              icon: Icons.pets,
              title: 'Animal Management Report',
              subtitle: 'Herd composition and status breakdown',
              iconColor: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnimalReportScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              icon: Icons.health_and_safety,
              title: 'Health Report',
              subtitle: 'Vaccinations, deworming, and treatments',
              iconColor: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HealthReportScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              icon: Icons.pregnant_woman,
              title: 'Breeding Report',
              subtitle: 'Heat detection, insemination, and calving',
              iconColor: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BreedingReportScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              icon: Icons.attach_money,
              title: 'Sales Report',
              subtitle: 'Revenue, liters sold, and price trends',
              iconColor: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesReportScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              icon: Icons.bar_chart,
              title: 'Financial Report',
              subtitle: 'Income, expenses, and profit analysis',
              iconColor: AppColors.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinancialReportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}