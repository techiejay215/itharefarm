// lib/screens/milk_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';

class MilkReportScreen extends StatefulWidget {
  const MilkReportScreen({super.key});

  @override
  State<MilkReportScreen> createState() => _MilkReportScreenState();
}

class _MilkReportScreenState extends State<MilkReportScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _milkRecords = [];
  Map<String, String> _earTags = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _firestore.getMilkReportData(_startDate, _endDate);
      final records = await _firestore.getMilkRecordsForDateRange(_startDate, _endDate);
      
      // Fetch ear tags for all animal IDs
      final animalIds = records.map((r) => r['animalId'] as String?).where((id) => id != null).cast<String>().toList();
      final tags = await _firestore.getAnimalEarTags(animalIds);
      
      if (!mounted) return;
      setState(() {
        _reportData = summary;
        _milkRecords = records;
        _earTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
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

  String _formatDate(DateTime date) => DateFormat('MMM dd, yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    if (RoleService.isWorker()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied for your role'), duration: Duration(seconds: 2)),
          );
          Navigator.pop(context);
        }
      });
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Milk Production Report'),
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
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Milk',
                      '${(_reportData['total_milk'] ?? 0).toStringAsFixed(0)} L',
                      Icons.water_drop,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildSummaryCard(
                      'Daily Average',
                      '${(_reportData['avg_daily'] ?? 0).toStringAsFixed(0)} L',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Session Breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Production by Session',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildSessionRow('🌅 Morning', _reportData['total_morning'] ?? 0),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSessionRow('☀️ Midday', _reportData['total_midday'] ?? 0),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSessionRow('🌙 Evening', _reportData['total_evening'] ?? 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Detailed Records
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Milk Records',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_milkRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No milk records in this period')),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _milkRecords.length,
                          itemBuilder: (context, index) {
                            final rec = _milkRecords[index];
                            final animalId = rec['animalId'] ?? '';
                            final earTag = _earTags[animalId] ?? animalId;
                            final date = rec['date'] ?? '';
                            final morning = (rec['morning'] as num?)?.toDouble() ?? 0;
                            final midday = (rec['midday'] as num?)?.toDouble() ?? 0;
                            final evening = (rec['evening'] as num?)?.toDouble() ?? 0;
                            final total = morning + midday + evening;
                            return ListTile(
                              title: Text('Cow #$earTag'),
                              subtitle: Text(date),
                              trailing: Text('$total L', style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: const TextStyle(fontSize: AppFontSizes.large, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: AppFontSizes.small, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildSessionRow(String session, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(session),
        Text(
          '${amount.toStringAsFixed(0)} L',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ],
    );
  }
}