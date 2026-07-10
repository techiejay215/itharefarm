// lib/screens/animal_report_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';  // ✅ Added

class AnimalReportScreen extends StatefulWidget {
  const AnimalReportScreen({super.key});

  @override
  State<AnimalReportScreen> createState() => _AnimalReportScreenState();
}

class _AnimalReportScreenState extends State<AnimalReportScreen> {
  final FirestoreService _firestore = FirestoreService();
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    final data = await _firestore.getAnimalReportData();
    
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

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
        title: const Text('Animal Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Text(
                        'Herd Summary',
                        style: TextStyle(
                          fontSize: AppFontSizes.medium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildStatRow('Total Animals', _reportData['total'] ?? 0),
                      _buildStatRow('Lactating', _reportData['lactating'] ?? 0),
                      _buildStatRow('Pregnant', _reportData['pregnant'] ?? 0),
                      _buildStatRow('Dry', _reportData['dry'] ?? 0),
                      _buildStatRow('Calves', _reportData['calf'] ?? 0),
                      _buildStatRow('Sold', _reportData['sold'] ?? 0),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text(
            value.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppFontSizes.medium,
            ),
          ),
        ],
      ),
    );
  }
}