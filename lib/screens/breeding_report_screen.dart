// lib/screens/breeding_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';

class BreedingReportScreen extends StatefulWidget {
  const BreedingReportScreen({super.key});

  @override
  State<BreedingReportScreen> createState() => _BreedingReportScreenState();
}

class _BreedingReportScreenState extends State<BreedingReportScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _breedingRecords = [];
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
      final summary = await _firestore.getBreedingReportData(_startDate, _endDate);
      final records = await _firestore.getBreedingRecordsForDateRange(_startDate, _endDate);
      
      final animalIds = records.map((r) => r['animalId'] as String?).where((id) => id != null).cast<String>().toList();
      final tags = await _firestore.getAnimalEarTags(animalIds);
      
      if (!mounted) return;
      setState(() {
        _reportData = summary;
        _breedingRecords = records;
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
        title: const Text('Breeding Report'),
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
                        'Breeding Summary',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildStatRow('Total Events', _reportData['total'] ?? 0),
                      _buildStatRow('Heat Detected', _reportData['heats'] ?? 0),
                      _buildStatRow('Inseminations', _reportData['inseminations'] ?? 0),
                      _buildStatRow('Pregnancies', _reportData['pregnancies'] ?? 0),
                      _buildStatRow('Calvings', _reportData['calvings'] ?? 0),
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
                        'Breeding Events',
                        style: TextStyle(fontSize: AppFontSizes.medium, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_breedingRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No breeding events in this period')),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _breedingRecords.length,
                          itemBuilder: (context, index) {
                            final rec = _breedingRecords[index];
                            final animalId = rec['animalId'] ?? '';
                            final earTag = _earTags[animalId] ?? animalId;
                            final event = rec['event_type'] ?? '';
                            final date = rec['date'] ?? '';
                            final notes = rec['notes'] ?? '';
                            return ListTile(
                              title: Text('$event – Cow #$earTag'),
                              subtitle: Text('$date ${notes.isNotEmpty ? ' • $notes' : ''}'),
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