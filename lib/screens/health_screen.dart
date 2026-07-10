// lib/screens/health_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  List<Map<String, dynamic>> _healthRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  List<Map<String, dynamic>> _todayTasks = [];
  
  String _selectedFilter = 'All';
  bool _isLoading = true;

  // Guards for parent methods
  bool _isAddingHealth = false;
  bool _isEditingHealth = false;

  final List<String> _filters = [
    'All', 'Vaccination', 'Deworming', 'Sickness', 'Vet Visit'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch all health records (not deleted)
    final snapshot = await _firestore.getHealthRecords().first;
    final records = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    // Enrich with animal data
    final enrichedRecords = <Map<String, dynamic>>[];
    for (var record in records) {
      final animalId = record['animalId'] as String?;
      if (animalId != null) {
        final animalDoc = await _firestore.getDocument('animals', animalId);
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          record['ear_tag'] = animalData['ear_tag'] ?? 'Unknown';
        } else {
          record['ear_tag'] = 'Unknown';
        }
      } else {
        record['ear_tag'] = 'Unknown';
      }
      enrichedRecords.add(record);
    }

    // Today's tasks: records where next_due == today
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayTasks = enrichedRecords.where((r) => r['next_due'] == today).toList();

    setState(() {
      _healthRecords = enrichedRecords;
      _filteredRecords = enrichedRecords;
      _todayTasks = todayTasks;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_selectedFilter == 'All') {
      setState(() => _filteredRecords = _healthRecords);
    } else {
      setState(() {
        _filteredRecords = _healthRecords
            .where((r) => r['type'] == _selectedFilter)
            .toList();
      });
    }
  }

  Future<void> _addHealthRecord() async {
    // Guard against double-tap
    if (_isAddingHealth) return;
    _isAddingHealth = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddHealthRecordDialog(),
    );
    if (result != null) {
      await _firestore.addHealthRecord(result);
      // Get animal ear tag for notification
      String earTag = 'Unknown';
      if (result['animalId'] != null) {
        final animalDoc = await _firestore.getDocument('animals', result['animalId']);
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          earTag = animalData['ear_tag'] ?? 'Unknown';
        }
      }
      await _firestore.addNotification({
        'title': 'Health Record Added',
        'message': '${result['type']} recorded for Cow #$earTag',
        'type': result['type'].toLowerCase(), // 'vaccination', 'deworming', etc.
        'is_read': false,
      });
      _loadData();
      _showSnackBar('Health record added');
    }

    _isAddingHealth = false;
  }

  // ---------- Edit Health Record ----------
  Future<void> _editHealthRecord(Map<String, dynamic> record) async {
    // Guard against double-tap
    if (_isEditingHealth) return;
    _isEditingHealth = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditHealthRecordDialog(record: record),
    );
    if (result != null) {
      await _firestore.updateHealthRecord(result['id'], result);
      await _firestore.addNotification({
        'title': 'Health Record Updated',
        'message': '${result['type']} updated for Cow #${record['ear_tag']}',
        'type': result['type'].toLowerCase(),
        'is_read': false,
      });
      _loadData();
      _showSnackBar('Health record updated');
    }

    _isEditingHealth = false;
  }

  // ---------- Delete Health Record ----------
  Future<void> _deleteHealthRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Health Record'),
        content: Text('Are you sure you want to delete this ${record['type']} record for Cow #${record['ear_tag']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteHealthRecord(record['id']);
      await _firestore.addNotification({
        'title': 'Health Record Deleted',
        'message': '${record['type']} record for Cow #${record['ear_tag']} was deleted',
        'type': 'health_deleted',
        'is_read': false,
      });
      _loadData();
      _showSnackBar('Health record deleted');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Vaccination': return Icons.vaccines;
      case 'Deworming': return Icons.medication;
      case 'Sickness': return Icons.sick;
      case 'Vet Visit': return Icons.local_hospital;
      default: return Icons.health_and_safety;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Vaccination': return Colors.blue;
      case 'Deworming': return Colors.green;
      case 'Sickness': return Colors.orange;
      case 'Vet Visit': return Colors.purple;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Records - Ithare Farm'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                if (value.isEmpty) {
                  _applyFilter();
                } else {
                  setState(() {
                    _filteredRecords = _filteredRecords
                        .where((r) => r['ear_tag'].toString().contains(value) ||
                              r['type'].toString().toLowerCase().contains(value.toLowerCase()))
                        .toList();
                  });
                }
              },
              decoration: const InputDecoration(hintText: 'Search by cow or type...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          // Filters
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter);
                      _applyFilter();
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? AppColors.white : AppColors.textDark),
                  ),
                );
              },
            ),
          ),
          // Today's tasks
          if (_todayTasks.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(alignment: Alignment.centerLeft, child: Text("Today's Health Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _todayTasks.length,
                itemBuilder: (context, index) {
                  final task = _todayTasks[index];
                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_getTypeIcon(task['type']), size: 20, color: AppColors.amber),
                            const SizedBox(width: 8),
                            Text(task['type'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.amber)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Cow #${task['ear_tag']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(task['description'] ?? 'No description', style: const TextStyle(fontSize: 12), maxLines: 1),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.health_and_safety, size: 64, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text('No health records found'),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 45, height: 45,
                                decoration: BoxDecoration(color: _getTypeColor(record['type']).withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(_getTypeIcon(record['type']), color: _getTypeColor(record['type'])),
                              ),
                              title: Text('${record['type']} - Cow #${record['ear_tag']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(record['description'] ?? 'No description'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('Date: ${_formatDate(record['date'])}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                      if (record['next_due'] != null) ...[
                                        const SizedBox(width: 12),
                                        Text('Next: ${_formatDate(record['next_due'])}', style: const TextStyle(fontSize: 12, color: AppColors.amber)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                                    onPressed: () => _editHealthRecord(record),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _deleteHealthRecord(record),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'health_fab',
        onPressed: _addHealthRecord,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }
}

// ---------- ADD HEALTH RECORD DIALOG ----------
class AddHealthRecordDialog extends StatefulWidget {
  const AddHealthRecordDialog({super.key});

  @override
  State<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<AddHealthRecordDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedAnimalId;
  String _selectedType = 'Vaccination';
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  List<Map<String, dynamic>> _animals = [];
  bool _isSaving = false;   // Guard flag

  final List<String> _types = ['Vaccination', 'Deworming', 'Sickness', 'Vet Visit'];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    final snapshot = await _firestore.getAnimals().first;
    final animals = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    setState(() => _animals = animals);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'animalId': _selectedAnimalId,
      'type': _selectedType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'description': _descriptionController.text,
      'next_due': _nextDueDate?.toIso8601String().split('T')[0],
      'notes': _notesController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Health Record'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedAnimalId,
                  isExpanded: true,
                  hint: const Text('Select Animal'),
                  items: _animals.map<DropdownMenuItem<String>>((animal) {
                    return DropdownMenuItem<String>(
                      value: animal['id'],
                      child: Text('Cow #${animal['ear_tag']} - ${animal['breed']}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAnimalId = v),
                  validator: (v) => v == null ? 'Select an animal' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Record Type'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                if (_selectedType == 'Vaccination' || _selectedType == 'Deworming')
                  ListTile(
                    title: const Text('Next Due Date'),
                    subtitle: _nextDueDate == null ? const Text('Not set') : Text(DateFormat('MMM dd, yyyy').format(_nextDueDate!)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _nextDueDate = date);
                    },
                  ),
              ],
            ),
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
}

// ---------- EDIT HEALTH RECORD DIALOG ----------
class EditHealthRecordDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  const EditHealthRecordDialog({super.key, required this.record});

  @override
  State<EditHealthRecordDialog> createState() => _EditHealthRecordDialogState();
}

class _EditHealthRecordDialogState extends State<EditHealthRecordDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  
  late String _selectedAnimalId;
  late String _selectedType;
  late DateTime _selectedDate;
  DateTime? _nextDueDate;
  List<Map<String, dynamic>> _animals = [];
  bool _isSaving = false;   // Guard flag

  final List<String> _types = ['Vaccination', 'Deworming', 'Sickness', 'Vet Visit'];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _selectedAnimalId = r['animalId'] as String;
    _selectedType = r['type'] as String;
    _selectedDate = DateTime.parse(r['date']);
    if (r['next_due'] != null) {
      _nextDueDate = DateTime.parse(r['next_due']);
    }
    _descriptionController = TextEditingController(text: r['description'] ?? '');
    _notesController = TextEditingController(text: r['notes'] ?? '');
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    final snapshot = await _firestore.getAnimals().first;
    final animals = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    setState(() => _animals = animals);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'id': widget.record['id'],
      'animalId': _selectedAnimalId,
      'type': _selectedType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'description': _descriptionController.text,
      'next_due': _nextDueDate?.toIso8601String().split('T')[0],
      'notes': _notesController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Health Record'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedAnimalId,
                  isExpanded: true,
                  hint: const Text('Select Animal'),
                  items: _animals.map<DropdownMenuItem<String>>((animal) {
                    return DropdownMenuItem<String>(
                      value: animal['id'],
                      child: Text('Cow #${animal['ear_tag']} - ${animal['breed']}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAnimalId = v!),
                  validator: (v) => v == null ? 'Select an animal' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Record Type'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                if (_selectedType == 'Vaccination' || _selectedType == 'Deworming')
                  ListTile(
                    title: const Text('Next Due Date'),
                    subtitle: _nextDueDate == null ? const Text('Not set') : Text(DateFormat('MMM dd, yyyy').format(_nextDueDate!)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _nextDueDate = date);
                    },
                  ),
              ],
            ),
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
}