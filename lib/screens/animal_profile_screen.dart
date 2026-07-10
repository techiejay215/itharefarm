// lib/screens/animal_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../models/animal_model.dart';
import '../models/milk_record_model.dart';
import '../models/health_record_model.dart';
import '../models/breeding_record_model.dart';

class AnimalProfileScreen extends StatefulWidget {
  final String animalId;
  final Animal? animal;

  const AnimalProfileScreen({
    super.key,
    required this.animalId,
    this.animal,
  });

  @override
  State<AnimalProfileScreen> createState() => _AnimalProfileScreenState();
}

class _AnimalProfileScreenState extends State<AnimalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestore = FirestoreService();

  Map<String, double> _todayMilk = {};
  List<MilkRecord> _milkHistory = [];
  List<HealthRecord> _healthRecords = [];
  List<BreedingRecord> _breedingRecords = [];
  bool _isLoading = true;
  Animal? _animal;
  String _animalDisplayName = '';

  // Guard flags for parent actions
  bool _isEditingAnimal = false;
  bool _isRecordingMilk = false;
  bool _isEditingMilkRecord = false;
  bool _isAddingHealth = false;
  bool _isEditingHealth = false;
  bool _isAddingBreeding = false;
  bool _isEditingBreeding = false;
  bool _isSettingReminder = false;

  // History filter date (null = show all)
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAnimalAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getAnimalDisplayName() {
    if (_animal == null) return 'Loading...';
    if (_animal!.name != null && _animal!.name!.isNotEmpty) {
      return _animal!.name!;
    }
    return '${_animal!.animalType ?? 'Cow'} #${_animal!.earTag}';
  }

  Future<void> _loadAnimalAndData() async {
    setState(() => _isLoading = true);

    if (widget.animal == null) {
      final doc = await _firestore.getDocument('animals', widget.animalId);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        _animal = Animal.fromMap(data);
      }
    } else {
      _animal = widget.animal;
    }

    if (_animal != null) {
      _animalDisplayName = _getAnimalDisplayName();
      await _loadAllData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    if (_animal == null) return;

    // Today's milk
    final today = DateTime.now().toIso8601String().split('T')[0];
    final milkSnapshot = await _firestore
        .getMilkRecordsForAnimal(widget.animalId)
        .first;
    final todayDocs = milkSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['date'] == today;
    }).toList();

    if (todayDocs.isNotEmpty) {
      final data = todayDocs.first.data() as Map<String, dynamic>;
      final morning = data['morning'] as num? ?? 0;
      final midday = data['midday'] as num? ?? 0;
      final evening = data['evening'] as num? ?? 0;
      _todayMilk = {
        'morning': morning.toDouble(),
        'midday': midday.toDouble(),
        'evening': evening.toDouble(),
        'total': (morning + midday + evening).toDouble(),
      };
    } else {
      _todayMilk = {'morning': 0, 'midday': 0, 'evening': 0, 'total': 0};
    }

    // Milk history
    final milkHistorySnapshot = await _firestore
        .getMilkRecordsForAnimal(widget.animalId)
        .first;
    _milkHistory = milkHistorySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return MilkRecord.fromMap(data);
    }).toList();

    // Health records
    final healthSnapshot = await _firestore
        .getCollectionStream('health_records')
        .first;
    _healthRecords = healthSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['animalId'] == widget.animalId)
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return HealthRecord.fromMap(data);
        }).toList();

    // Breeding records
    final breedingSnapshot = await _firestore
        .getCollectionStream('breeding_records')
        .first;
    _breedingRecords = breedingSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['animalId'] == widget.animalId)
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return BreedingRecord.fromMap(data);
        }).toList();

    setState(() => _isLoading = false);
  }

  String _formatDate(String? date) {
    if (date == null) return 'Not recorded';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  // ========== History filter helpers ==========
  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  void _clearFilterDate() {
    setState(() => _filterDate = null);
  }

  // ========== EDIT / DELETE ANIMAL ==========

  Future<void> _editAnimal() async {
    if (_isEditingAnimal) return;
    _isEditingAnimal = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditAnimalDialog(animal: _animal!),
    );
    if (result != null) {
      await _firestore.updateAnimal(_animal!.id!, result);
      _loadAnimalAndData();
      _showSnackBar('Animal updated');
    }

    _isEditingAnimal = false;
  }

  Future<void> _deleteAnimal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $_animalDisplayName'),
        content: const Text(
            'Are you sure you want to delete this animal? All associated records (milk, health, breeding) will also be deleted. This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteAnimal(_animal!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  // ========== QUICK ACTIONS ==========

  Future<void> _recordMilk() async {
    if (_isRecordingMilk) return;
    _isRecordingMilk = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMilkRecordDialog(
        animalId: _animal!.id!,
        animalName: _animalDisplayName,
      ),
    );
    if (result != null) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snapshot = await _firestore
          .getMilkRecordsForAnimal(_animal!.id!)
          .first;
      final existing = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['date'] == today;
      }).toList();

      if (existing.isNotEmpty) {
        await _firestore.updateMilkRecord(existing.first.id, {
          'morning': result['morning'],
          'midday': result['midday'],
          'evening': result['evening'],
        });
      } else {
        await _firestore.addMilkRecord({
          'animalId': _animal!.id!,
          'date': today,
          'morning': result['morning'],
          'midday': result['midday'],
          'evening': result['evening'],
        });
      }
      _loadAllData();
      _showSnackBar('Milk record added');
    }

    _isRecordingMilk = false;
  }

  Future<void> _editMilkRecord(MilkRecord record) async {
    if (_isEditingMilkRecord) return;
    _isEditingMilkRecord = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditMilkRecordDialog(
        animalName: _animalDisplayName,
        record: record,
      ),
    );
    if (result != null) {
      await _firestore.updateMilkRecord(record.id!, result);
      _loadAllData();
      _showSnackBar('Milk record updated');
    }

    _isEditingMilkRecord = false;
  }

  Future<void> _deleteMilkRecord(MilkRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Milk Record'),
        content: Text('Delete milk record for ${_formatDate(record.date)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteMilkRecord(record.id!);
      _loadAllData();
      _showSnackBar('Milk record deleted');
    }
  }

  // ----- Health -----
  Future<void> _addHealthRecord() async {
    if (_isAddingHealth) return;
    _isAddingHealth = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddHealthRecordDialog(
        animalId: _animal!.id!,
        animalName: _animalDisplayName,
      ),
    );
    if (result != null) {
      await _firestore.addHealthRecord(result);
      _loadAllData();
      _showSnackBar('Health record added');
    }

    _isAddingHealth = false;
  }

  Future<void> _editHealthRecord(HealthRecord record) async {
    if (_isEditingHealth) return;
    _isEditingHealth = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditHealthRecordDialog(
        record: record,
        animalName: _animalDisplayName,
      ),
    );
    if (result != null) {
      await _firestore.updateHealthRecord(record.id!, result);
      _loadAllData();
      _showSnackBar('Health record updated');
    }

    _isEditingHealth = false;
  }

  Future<void> _deleteHealthRecord(HealthRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Health Record'),
        content: Text('Delete this ${record.type} record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteHealthRecord(record.id!);
      _loadAllData();
      _showSnackBar('Health record deleted');
    }
  }

  // ----- Breeding -----
  Future<void> _addBreedingRecord() async {
    if (_isAddingBreeding) return;
    _isAddingBreeding = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddBreedingRecordDialog(
        animalId: _animal!.id!,
        animalName: _animalDisplayName,
      ),
    );
    if (result != null) {
      await _firestore.addBreedingRecord(result);
      _loadAllData();
      _showSnackBar('Breeding record added');
    }

    _isAddingBreeding = false;
  }

  Future<void> _editBreedingRecord(BreedingRecord record) async {
    if (_isEditingBreeding) return;
    _isEditingBreeding = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditBreedingRecordDialog(
        record: record,
        animalName: _animalDisplayName,
      ),
    );
    if (result != null) {
      await _firestore.updateBreedingRecord(record.id!, result);
      _loadAllData();
      _showSnackBar('Breeding record updated');
    }

    _isEditingBreeding = false;
  }

  Future<void> _deleteBreedingRecord(BreedingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Breeding Record'),
        content: Text('Delete ${record.eventType} record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteBreedingRecord(record.id!);
      _loadAllData();
      _showSnackBar('Breeding record deleted');
    }
  }

  // ----- Reminder -----
  void _showSetReminderDialog() {
    if (_isSettingReminder) return;
    _isSettingReminder = true;

    showDialog(
      context: context,
      builder: (context) => SetReminderDialog(
        animalName: _animalDisplayName,
        animalId: _animal!.id!,
      ),
    ).then((_) {
      _isSettingReminder = false;
      _loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_animal == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Animal Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets, size: 64, color: AppColors.textLight),
              SizedBox(height: 16),
              Text('Animal not found'),
            ],
          ),
        ),
      );
    }

    final statusStyle = _animal!.getStatusStyle();
    final isCow = _animal!.animalType == 'Cow';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_animalDisplayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: _showSetReminderDialog,
            tooltip: 'Set Reminder',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editAnimal,
            tooltip: 'Edit Animal',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteAnimal,
            tooltip: 'Delete Animal',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Milk'),
            Tab(text: 'Health'),
            Tab(text: 'Breeding'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(statusStyle, isCow),
                _buildMilkTab(),
                _buildHealthTab(),
                _buildBreedingTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  // ========== OVERVIEW TAB ==========
  Widget _buildOverviewTab(Map<String, String> statusStyle, bool isCow) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _animal!.animalType == 'Bull'
                        ? Icons.agriculture
                        : (_animal!.animalType == 'Heifer'
                            ? Icons.pets
                            : Icons.emoji_emotions_outlined),
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _animalDisplayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _animal!.breed,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ear Tag: #${_animal!.earTag} | Type: ${_animal!.animalType ?? 'Cow'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                // Show status only for cows
                if (isCow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(int.parse(statusStyle['bg']!.substring(1, 7), radix: 16) + 0xFF000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _animal!.status,
                      style: TextStyle(
                        color: Color(int.parse(statusStyle['text']!.substring(1, 7), radix: 16) + 0xFF000000),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'N/A',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Name', _animal!.name ?? 'Not set'),
                  const Divider(),
                  if (isCow) _buildInfoRow('Status', _animal!.status),
                  if (isCow) const Divider(),
                  _buildInfoRow('Breed', _animal!.breed),
                  const Divider(),
                  _buildInfoRow('Ear Tag', '#${_animal!.earTag}'),
                  const Divider(),
                  _buildInfoRow('Animal Type', _animal!.animalType ?? 'Cow'),
                  const Divider(),
                  _buildInfoRow('Last Calving', _formatDate(_animal!.lastCalving)),
                  const Divider(),
                  _buildInfoRow('Mother\'s Name', _animal!.motherName ?? 'Not recorded'),
                  const Divider(),
                  _buildInfoRow('Date of Birth', _formatDate(_animal!.dateOfBirth)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Milk",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMilkSession('Morning', _todayMilk['morning'] ?? 0),
                      _buildMilkSession('Midday', _todayMilk['midday'] ?? 0),
                      _buildMilkSession('Evening', _todayMilk['evening'] ?? 0),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow('Total', '${(_todayMilk['total'] ?? 0).toStringAsFixed(0)} L'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recordMilk,
                  icon: const Icon(Icons.water_drop, size: 18),
                  label: const Text('Record Milk'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addHealthRecord,
                  icon: const Icon(Icons.health_and_safety, size: 18),
                  label: const Text('Add Health Record'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addBreedingRecord,
                  icon: const Icon(Icons.pregnant_woman, size: 18),
                  label: const Text('Add Breeding Record'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== MILK TAB ==========
  Widget _buildMilkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Today's Milk",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMilkSession('Morning', _todayMilk['morning'] ?? 0),
                    _buildMilkSession('Midday', _todayMilk['midday'] ?? 0),
                    _buildMilkSession('Evening', _todayMilk['evening'] ?? 0),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Today'),
                    Text(
                      '${(_todayMilk['total'] ?? 0).toStringAsFixed(0)} L',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recent Records',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_milkHistory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No milk records yet'),
            ),
          )
        else
          ..._milkHistory.map((record) => Dismissible(
            key: Key(record.id!),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Milk Record'),
                  content: Text('Delete milk record for ${_formatDate(record.date)}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (_) => _deleteMilkRecord(record),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_formatDate(record.date)),
                subtitle: Text(
                  '🌅 ${record.morning.toStringAsFixed(0)}L  ☀️ ${record.midday.toStringAsFixed(0)}L  🌙 ${record.evening.toStringAsFixed(0)}L',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${record.total.toStringAsFixed(0)}L',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                      onPressed: () => _editMilkRecord(record),
                    ),
                  ],
                ),
              ),
            ),
          )),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _recordMilk,
            icon: const Icon(Icons.add),
            label: const Text('Add Milk Record'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ========== HEALTH TAB ==========
  Widget _buildHealthTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_healthRecords.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.health_and_safety, size: 48, color: AppColors.textLight),
                  SizedBox(height: 12),
                  Text('No health records yet'),
                ],
              ),
            ),
          )
        else
          ..._healthRecords.map((record) {
            IconData icon;
            Color color;
            switch (record.type) {
              case 'Vaccination':
                icon = Icons.vaccines;
                color = Colors.blue;
                break;
              case 'Deworming':
                icon = Icons.medication;
                color = Colors.green;
                break;
              default:
                icon = Icons.health_and_safety;
                color = Colors.orange;
            }
            return Dismissible(
              key: Key(record.id!),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Health Record'),
                    content: Text('Delete this ${record.type} record?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (_) => _deleteHealthRecord(record),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(record.type),
                  subtitle: Text(record.description ?? 'No description'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatDate(record.date)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                        onPressed: () => _editHealthRecord(record),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addHealthRecord,
            icon: const Icon(Icons.add),
            label: const Text('Add Health Record'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ========== BREEDING TAB ==========
  Widget _buildBreedingTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_breedingRecords.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.pregnant_woman, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text('No breeding records yet'),
                      ],
                    ),
                  ),
                )
              else
                ..._breedingRecords.map((record) {
                  IconData icon;
                  switch (record.eventType) {
                    case 'Heat Detected':
                      icon = Icons.local_fire_department;
                      break;
                    case 'Inseminated':
                      icon = Icons.medical_services;
                      break;
                    case 'Pregnancy Confirmed':
                      icon = Icons.pregnant_woman;
                      break;
                    case 'Calved':
                      icon = Icons.celebration;
                      break;
                    default:
                      icon = Icons.event;
                  }
                  return Dismissible(
                    key: Key(record.id!),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Breeding Record'),
                          content: Text('Delete ${record.eventType} record?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) => _deleteBreedingRecord(record),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(icon, color: AppColors.primary),
                        title: Text(record.eventType),
                        subtitle: record.notes != null && record.notes!.isNotEmpty
                            ? Text(record.notes!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatDate(record.date)),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                              onPressed: () => _editBreedingRecord(record),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addBreedingRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add Breeding Record'),
            ),
          ),
        ),
      ],
    );
  }

  // ========== HISTORY TAB (FULLY FUNCTIONAL) ==========
Widget _buildHistoryTab() {
  // Build a combined list of all events with type info
  List<Map<String, dynamic>> allEvents = [];

  for (var record in _milkHistory) {
    allEvents.add({
      'type': 'milk',
      'record': record,
      'date': record.date,
      'title': 'Milk Production',
      'subtitle': '🌅 ${record.morning.toStringAsFixed(0)}L  ☀️ ${record.midday.toStringAsFixed(0)}L  🌙 ${record.evening.toStringAsFixed(0)}L  = ${record.total.toStringAsFixed(0)}L total',
      'icon': Icons.water_drop,
    });
  }
  for (var record in _healthRecords) {
    allEvents.add({
      'type': 'health',
      'record': record,
      'date': record.date,
      'title': record.type,
      'subtitle': record.description ?? '',
      'icon': Icons.health_and_safety,
    });
  }
  for (var record in _breedingRecords) {
    allEvents.add({
      'type': 'breeding',
      'record': record,
      'date': record.date,
      'title': record.eventType,
      'subtitle': record.notes ?? '',
      'icon': Icons.pregnant_woman,
    });
  }

  // Apply date filter if set
  if (_filterDate != null) {
    final filterStr = DateFormat('yyyy-MM-dd').format(_filterDate!);
    allEvents = allEvents.where((e) => e['date'] == filterStr).toList();
  }

  // Sort by date descending (most recent first)
  allEvents.sort((a, b) => b['date'].compareTo(a['date']));

  return Column(
    children: [
      // Filter row – fixed with Expanded to avoid infinite width
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickFilterDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _filterDate == null
                      ? 'Filter by date'
                      : DateFormat('MMM dd, yyyy').format(_filterDate!),
                ),
              ),
            ),
            if (_filterDate != null)
              TextButton(
                onPressed: _clearFilterDate,
                child: const Text('Clear filter'),
              ),
          ],
        ),
      ),

      // List of events
      Expanded(
        child: allEvents.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No records for this date'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allEvents.length,
                itemBuilder: (context, index) {
                  final event = allEvents[index];
                  final record = event['record'];
                  final type = event['type'];

                  return Dismissible(
                    key: Key('${type}_${record.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Record'),
                          content: Text('Delete this ${event['title']} record?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) {
                      switch (type) {
                        case 'milk':
                          _deleteMilkRecord(record);
                          break;
                        case 'health':
                          _deleteHealthRecord(record);
                          break;
                        case 'breeding':
                          _deleteBreedingRecord(record);
                          break;
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Open the edit dialog
                          switch (type) {
                            case 'milk':
                              _editMilkRecord(record);
                              break;
                            case 'health':
                              _editHealthRecord(record);
                              break;
                            case 'breeding':
                              _editBreedingRecord(record);
                              break;
                          }
                        },
                        child: ListTile(
                          leading: Icon(event['icon'], color: AppColors.primary),
                          title: Text(event['title']),
                          subtitle: event['subtitle'].isNotEmpty ? Text(event['subtitle']) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_formatDate(event['date'])),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                onPressed: () {
                                  switch (type) {
                                    case 'milk':
                                      _editMilkRecord(record);
                                      break;
                                    case 'health':
                                      _editHealthRecord(record);
                                      break;
                                    case 'breeding':
                                      _editBreedingRecord(record);
                                      break;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
  // ========== HELPERS ==========
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMilkSession(String session, double amount) {
    return Column(
      children: [
        Text(session, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(0)} L',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ===================================================================
// DIALOGS – All dialogs with overflow fixes and save-guard
// ===================================================================

// ---------- Edit Animal Dialog ----------
class EditAnimalDialog extends StatefulWidget {
  final Animal animal;
  const EditAnimalDialog({super.key, required this.animal});
  @override
  State<EditAnimalDialog> createState() => _EditAnimalDialogState();
}

class _EditAnimalDialogState extends State<EditAnimalDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _motherNameController;
  late String _selectedStatus;
  late String _selectedType;
  late String _lastCalving;
  DateTime? _dateOfBirth;
  bool _isSaving = false;

  final List<String> _statusOptions = ['Lactating', 'Pregnant', 'Dry', 'Calf', 'Sold'];
  final List<String> _typeOptions = ['Cow', 'Bull', 'Heifer'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.animal.name ?? '');
    _breedController = TextEditingController(text: widget.animal.breed);
    _motherNameController = TextEditingController(text: widget.animal.motherName ?? '');
    _selectedStatus = widget.animal.status;
    _selectedType = widget.animal.animalType ?? 'Cow';
    _lastCalving = widget.animal.lastCalving ?? '';
    _dateOfBirth = widget.animal.dateOfBirth != null
        ? DateTime.tryParse(widget.animal.dateOfBirth!)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _motherNameController.dispose();
    super.dispose();
  }

  bool get isCow => _selectedType == 'Cow';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Animal'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name (Optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: 'Breed'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(labelText: 'Animal Type'),
              ),
              const SizedBox(height: 12),
              if (isCow)
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                  decoration: const InputDecoration(labelText: 'Status'),
                )
              else
                const Text('Status not applicable for Bulls and Calves'),
              if (!isCow) const SizedBox(height: 12),
              TextFormField(
                initialValue: _lastCalving,
                decoration: const InputDecoration(labelText: 'Last Calving (YYYY-MM-DD)'),
                onChanged: (v) => _lastCalving = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motherNameController,
                decoration: const InputDecoration(labelText: 'Mother\'s Name (Optional)'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _dateOfBirth = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date of Birth (Optional)'),
                      Text(
                        _dateOfBirth == null
                            ? 'Not set'
                            : DateFormat('MMM dd, yyyy').format(_dateOfBirth!),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text.isEmpty ? null : _nameController.text,
      'breed': _breedController.text,
      'animal_type': _selectedType,
      'last_calving': _lastCalving.isEmpty ? null : _lastCalving,
      'mother_name': _motherNameController.text.isEmpty ? null : _motherNameController.text,
      'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0],
    };
    if (isCow) data['status'] = _selectedStatus;

    Navigator.pop(context, data);
  }
}

// ---------- Edit Milk Record Dialog ----------
class EditMilkRecordDialog extends StatefulWidget {
  final String animalName;
  final MilkRecord record;
  const EditMilkRecordDialog({super.key, required this.animalName, required this.record});

  @override
  State<EditMilkRecordDialog> createState() => _EditMilkRecordDialogState();
}

class _EditMilkRecordDialogState extends State<EditMilkRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _morningController;
  late TextEditingController _middayController;
  late TextEditingController _eveningController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _morningController = TextEditingController(text: widget.record.morning.toStringAsFixed(0));
    _middayController = TextEditingController(text: widget.record.midday.toStringAsFixed(0));
    _eveningController = TextEditingController(text: widget.record.evening.toStringAsFixed(0));
    _selectedDate = DateTime.parse(widget.record.date);
  }

  @override
  void dispose() {
    _morningController.dispose();
    _middayController.dispose();
    _eveningController.dispose();
    super.dispose();
  }

  double _getDouble(String value) => double.tryParse(value) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Milk - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _morningController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Morning (L)',
                  prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _middayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Midday (L)',
                  prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eveningController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Evening (L)',
                  prefixIcon: Icon(Icons.nightlight_round, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'morning': _getDouble(_morningController.text),
      'midday': _getDouble(_middayController.text),
      'evening': _getDouble(_eveningController.text),
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}

// ---------- Add Milk Record Dialog ----------
class AddMilkRecordDialog extends StatefulWidget {
  final String animalId;
  final String animalName;
  const AddMilkRecordDialog({super.key, required this.animalId, required this.animalName});

  @override
  State<AddMilkRecordDialog> createState() => _AddMilkRecordDialogState();
}

class _AddMilkRecordDialogState extends State<AddMilkRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _morningController = TextEditingController();
  final _middayController = TextEditingController();
  final _eveningController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _morningController.dispose();
    _middayController.dispose();
    _eveningController.dispose();
    super.dispose();
  }

  double _getDouble(String value) => double.tryParse(value) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Milk - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _morningController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Morning (L)',
                  prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _middayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Midday (L)',
                  prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eveningController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Evening (L)',
                  prefixIcon: Icon(Icons.nightlight_round, size: 18),
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'date': _selectedDate.toIso8601String().split('T')[0],
      'morning': _getDouble(_morningController.text),
      'midday': _getDouble(_middayController.text),
      'evening': _getDouble(_eveningController.text),
    });
  }
}

// ---------- Add Health Record Dialog ----------
class AddHealthRecordDialog extends StatefulWidget {
  final String animalId;
  final String animalName;
  const AddHealthRecordDialog({super.key, required this.animalId, required this.animalName});

  @override
  State<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<AddHealthRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedType = 'Vaccination';
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  bool _isSaving = false;
  final List<String> _types = ['Vaccination', 'Deworming', 'Sickness', 'Vet Visit'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Health Record - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(
                  labelText: 'Record Type',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              if (_selectedType == 'Vaccination' || _selectedType == 'Deworming') ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _nextDueDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Next Due Date'),
                        Text(
                          _nextDueDate == null
                              ? 'Not set'
                              : DateFormat('MMM dd, yyyy').format(_nextDueDate!),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final nextDueStr = _nextDueDate?.toIso8601String().split('T')[0];
    final record = {
      'animalId': widget.animalId,
      'type': _selectedType,
      'date': dateStr,
      'description': _descriptionController.text,
      'next_due': nextDueStr,
    };
    if (nextDueStr != null) {
      await FirestoreService().addNotification({
        'title': '$_selectedType Reminder',
        'message': '${widget.animalName} has $_selectedType due on ${DateFormat('MMM dd, yyyy').format(_nextDueDate!)}',
        'type': _selectedType.toLowerCase(),
        'is_read': false,
      });
    }
    Navigator.pop(context, record);
  }
}

// ---------- Edit Health Record Dialog ----------
class EditHealthRecordDialog extends StatefulWidget {
  final HealthRecord record;
  final String animalName;
  const EditHealthRecordDialog({super.key, required this.record, required this.animalName});

  @override
  State<EditHealthRecordDialog> createState() => _EditHealthRecordDialogState();
}

class _EditHealthRecordDialogState extends State<EditHealthRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late String _selectedType;
  late DateTime _selectedDate;
  DateTime? _nextDueDate;
  bool _isSaving = false;
  final List<String> _types = ['Vaccination', 'Deworming', 'Sickness', 'Vet Visit'];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _selectedType = r.type;
    _selectedDate = DateTime.parse(r.date);
    _nextDueDate = r.nextDue != null ? DateTime.parse(r.nextDue!) : null;
    _descriptionController = TextEditingController(text: r.description ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Health - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(
                  labelText: 'Record Type',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              if (_selectedType == 'Vaccination' || _selectedType == 'Deworming') ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _nextDueDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Next Due Date'),
                        Text(
                          _nextDueDate == null
                              ? 'Not set'
                              : DateFormat('MMM dd, yyyy').format(_nextDueDate!),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'id': widget.record.id,
      'type': _selectedType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'description': _descriptionController.text,
      'next_due': _nextDueDate?.toIso8601String().split('T')[0],
    });
  }
}

// ---------- Add Breeding Record Dialog ----------
class AddBreedingRecordDialog extends StatefulWidget {
  final String animalId;
  final String animalName;
  const AddBreedingRecordDialog({super.key, required this.animalId, required this.animalName});

  @override
  State<AddBreedingRecordDialog> createState() => _AddBreedingRecordDialogState();
}

class _AddBreedingRecordDialogState extends State<AddBreedingRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String _selectedEventType = 'Heat Detected';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  final List<String> _eventTypes = [
    'Heat Detected', 'Inseminated', 'Pregnancy Confirmed', 'Pregnancy Negative',
    'Expected Calving', 'Calved', 'Dry Off',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Breeding - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedEventType = v!),
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'animalId': widget.animalId,
      'event_type': _selectedEventType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'notes': _notesController.text,
    });
  }
}

// ---------- Edit Breeding Record Dialog ----------
class EditBreedingRecordDialog extends StatefulWidget {
  final BreedingRecord record;
  final String animalName;
  const EditBreedingRecordDialog({super.key, required this.record, required this.animalName});

  @override
  State<EditBreedingRecordDialog> createState() => _EditBreedingRecordDialogState();
}

class _EditBreedingRecordDialogState extends State<EditBreedingRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  late String _selectedEventType;
  late DateTime _selectedDate;
  bool _isSaving = false;
  final List<String> _eventTypes = [
    'Heat Detected', 'Inseminated', 'Pregnancy Confirmed', 'Pregnancy Negative',
    'Expected Calving', 'Calved', 'Dry Off',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _selectedEventType = r.eventType;
    _selectedDate = DateTime.parse(r.date);
    _notesController = TextEditingController(text: r.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Breeding - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedEventType = v!),
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'id': widget.record.id,
      'event_type': _selectedEventType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'notes': _notesController.text,
    });
  }
}

// ---------- Set Reminder Dialog ----------
class SetReminderDialog extends StatefulWidget {
  final String animalName;
  final String animalId;
  const SetReminderDialog({super.key, required this.animalName, required this.animalId});

  @override
  State<SetReminderDialog> createState() => _SetReminderDialogState();
}

class _SetReminderDialogState extends State<SetReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _reminderDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Reminder - ${widget.animalName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _reminderDate ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _reminderDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reminder Date'),
                      Text(
                        _reminderDate == null
                            ? 'Select date (optional)'
                            : DateFormat('MMM dd, yyyy').format(_reminderDate!),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Set Reminder'),
        ),
      ],
    );
  }

  void _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final notification = {
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
      'type': 'manual',
      'is_read': false,
      'created_at': _reminderDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
    await FirestoreService().addNotification(notification);
    if (mounted) Navigator.pop(context);
  }
}