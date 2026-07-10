// lib/screens/health_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _healthRecords = [];
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
      final summary = await _firestore.getHealthReportData(_startDate, _endDate);
      final records = await _firestore.getHealthRecordsForDateRange(_startDate, _endDate);
      
      final animalIds = records.map((r) => r['animalId'] as String?).where((id) => id != null).cast<String>().toList();
      final tags = await _firestore.getAnimalEarTags(animalIds);
      
      if (!mounted) return;
      setState(() {
        _reportData = summary;
        _healthRecords = records;
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
        title: const Text('Health Report'),
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
                        'Health Summary',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildStatRow('Total Records', _reportData['total'] ?? 0),
                      _buildStatRow('Vaccinations', _reportData['vaccinations'] ?? 0),
                      _buildStatRow('Deworming', _reportData['deworming'] ?? 0),
                      _buildStatRow('Sickness Cases', _reportData['sickness'] ?? 0),
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
                        'Health Events',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_healthRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No health records in this period')),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _healthRecords.length,
                          itemBuilder: (context, index) {
                            final rec = _healthRecords[index];
                            final animalId = rec['animalId'] ?? '';
                            final earTag = _earTags[animalId] ?? animalId;
                            final type = rec['type'] ?? '';
                            final date = rec['date'] ?? '';
                            final desc = rec['description'] ?? '';
                            return ListTile(
                              title: Text('$type – Cow #$earTag'),
                              subtitle: Text('$date ${desc.isNotEmpty ? ' • $desc' : ''}'),
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

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppFontSizes.medium)),
        ],
      ),
    );
  }
}