// lib/screens/sales_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';  // ✅ Added

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
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
    
    final data = await _firestore.getSalesReportData(_startDate, _endDate);
    
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
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
        title: const Text('Sales Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: Text('${_formatDate(_startDate)} - ${_formatDate(_endDate)}'),
                trailing: const Icon(Icons.edit),
                onTap: _selectDateRange,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Text(
                        'Sales Summary',
                        style: TextStyle(
                          fontSize: AppFontSizes.medium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildStatRow('Total Revenue', 'Ksh ${(_reportData['total_revenue'] ?? 0).toStringAsFixed(0)}'),
                      _buildStatRow('Total Litres', '${(_reportData['total_litres'] ?? 0).toStringAsFixed(0)} L'),
                      _buildStatRow('Average Price', 'Ksh ${(_reportData['avg_price'] ?? 0).toStringAsFixed(0)}/L'),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppFontSizes.medium,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}