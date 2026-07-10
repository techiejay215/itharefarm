// lib/screens/breeding_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';

class BreedingScreen extends StatefulWidget {
  const BreedingScreen({super.key});

  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<Map<String, dynamic>> _upcomingCalvings = [];
  List<Map<String, dynamic>> _upcomingHeats = [];
  List<Map<String, dynamic>> _recentlyBred = [];
  List<Map<String, dynamic>> _allRecords = [];

  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  bool _isAddingBreeding = false; // ← guard for parent method

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final calvings = await _firestore.getUpcomingCalvings();
    final heats = await _firestore.getUpcomingHeats();
    final recentlyBred = await _firestore.getRecentlyBred();
    final allRecords = await _firestore.getAllBreedingRecords();

    setState(() {
      _upcomingCalvings = calvings;
      _upcomingHeats = heats;
      _recentlyBred = recentlyBred;
      _allRecords = allRecords;
      _isLoading = false;
    });
  }

  Future<void> _addBreedingRecord() async {
    if (_isAddingBreeding) return;
    _isAddingBreeding = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddBreedingRecordDialog(),
    );

    if (result != null) {
      await _firestore.addBreedingRecord(result);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Breeding record added'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }

    _isAddingBreeding = false;
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  String _formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  int _daysRemaining(String date) {
    try {
      final target = DateTime.parse(date);
      final today = DateTime.now();
      return target.difference(today).inDays;
    } catch (e) {
      return 0;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'Heat Detected':
        return Icons.local_fire_department;
      case 'Inseminated':
        return Icons.medical_services;
      case 'Pregnancy Confirmed':
        return Icons.pregnant_woman;
      case 'Pregnancy Negative':
        return Icons.sentiment_dissatisfied;
      case 'Expected Calving':
        return Icons.celebration;
      case 'Calved':
        return Icons.celebration;
      case 'Dry Off':
        return Icons.coffee;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'Heat Detected':
        return AppColors.amber;
      case 'Inseminated':
        return Colors.blue;
      case 'Pregnancy Confirmed':
        return Colors.green;
      case 'Pregnancy Negative':
        return Colors.red;
      case 'Expected Calving':
        return Colors.purple;
      case 'Calved':
        return Colors.teal;
      case 'Dry Off':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  void _showSetReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => SetReminderDialog(
        animalName: null, // general reminder, no specific animal
        animalId: null,
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Breeding - Ithare Farm'),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Calendar Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📅 ${_formatMonth(_currentMonth)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _changeMonth(1),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Upcoming Events Section
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Upcoming Calvings
                  if (_upcomingCalvings.isNotEmpty) ...[
                    ..._upcomingCalvings.map((calving) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.celebration, color: Colors.purple),
                            ),
                            title: Text('Cow #${calving['ear_tag']}'),
                            subtitle: Text('Expected Calving - ${_formatDate(calving['date'])}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_daysRemaining(calving['date'])} days',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],

                  // Upcoming Heats
                  if (_upcomingHeats.isNotEmpty) ...[
                    ..._upcomingHeats.map((heat) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: AppColors.amber.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_fire_department, color: AppColors.amber),
                            ),
                            title: Text('Cow #${heat['ear_tag']}'),
                            subtitle: Text('Heat Expected - ${_formatDate(heat['date'])}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_daysRemaining(heat['date'])} days',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.amber,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],

                  if (_upcomingCalvings.isEmpty && _upcomingHeats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No upcoming events'),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Recently Bred Section
                  const Text(
                    'Recently Bred',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_recentlyBred.isNotEmpty)
                    ..._recentlyBred.map((bred) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.medical_services, color: Colors.blue),
                            ),
                            title: Text('Cow #${bred['ear_tag']}'),
                            subtitle: Text('Inseminated - ${_formatDate(bred['date'])}'),
                            trailing: Text(
                              bred['notes'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                            ),
                            onTap: () => _viewAnimalBreedingTimeline(bred['animalId'], bred['ear_tag']),
                          ),
                        ))
                  else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No breeding records'),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // All Breeding Records
                  const Text(
                    'All Breeding Records',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_allRecords.isNotEmpty)
                    ..._allRecords.take(10).map((record) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getEventColor(record['event_type']).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getEventIcon(record['event_type']),
                                size: 20,
                                color: _getEventColor(record['event_type']),
                              ),
                            ),
                            title: Text('Cow #${record['ear_tag']}'),
                            subtitle: Text(record['event_type']),
                            trailing: Text(_formatDate(record['date'])),
                            onTap: () => _viewAnimalBreedingTimeline(record['animalId'], record['ear_tag']),
                          ),
                        ))
                  else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No breeding records'),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Add Breeding Record Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addBreedingRecord,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Breeding Record'),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'breeding_fab',
        onPressed: _addBreedingRecord,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  void _viewAnimalBreedingTimeline(String animalId, String earTag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AnimalBreedingTimelineSheet(animalId: animalId, earTag: earTag),
    );
  }
}

// Animal Breeding Timeline Bottom Sheet
class AnimalBreedingTimelineSheet extends StatefulWidget {
  final String animalId;
  final String earTag;

  const AnimalBreedingTimelineSheet({
    super.key,
    required this.animalId,
    required this.earTag,
  });

  @override
  State<AnimalBreedingTimelineSheet> createState() => _AnimalBreedingTimelineSheetState();
}

class _AnimalBreedingTimelineSheetState extends State<AnimalBreedingTimelineSheet> {
  final FirestoreService _firestore = FirestoreService();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await _firestore.getBreedingRecordsForAnimal(widget.animalId);
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'Heat Detected':
        return Icons.local_fire_department;
      case 'Inseminated':
        return Icons.medical_services;
      case 'Pregnancy Confirmed':
        return Icons.pregnant_woman;
      case 'Pregnancy Negative':
        return Icons.sentiment_dissatisfied;
      case 'Expected Calving':
        return Icons.celebration;
      case 'Calved':
        return Icons.celebration;
      case 'Dry Off':
        return Icons.coffee;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'Heat Detected':
        return AppColors.amber;
      case 'Inseminated':
        return Colors.blue;
      case 'Pregnancy Confirmed':
        return Colors.green;
      case 'Pregnancy Negative':
        return Colors.red;
      case 'Expected Calving':
        return Colors.purple;
      case 'Calved':
        return Colors.teal;
      case 'Dry Off':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cow #${widget.earTag} - Breeding Timeline',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pregnant_woman, size: 64, color: AppColors.textLight),
                                SizedBox(height: 12),
                                Text('No breeding records'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: _getEventColor(record['event_type']).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getEventIcon(record['event_type']),
                                        color: _getEventColor(record['event_type']),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            record['event_type'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          if (record['notes'] != null)
                                            Text(
                                              record['notes'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatDate(record['date']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Add Breeding Record Dialog
class AddBreedingRecordDialog extends StatefulWidget {
  const AddBreedingRecordDialog({super.key});

  @override
  State<AddBreedingRecordDialog> createState() => _AddBreedingRecordDialogState();
}

class _AddBreedingRecordDialogState extends State<AddBreedingRecordDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _selectedAnimalId;
  String _selectedEventType = 'Heat Detected';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false; // ← guard flag

  List<Map<String, dynamic>> _animals = [];

  final List<String> _eventTypes = [
    'Heat Detected',
    'Inseminated',
    'Pregnancy Confirmed',
    'Pregnancy Negative',
    'Expected Calving',
    'Calved',
    'Dry Off',
  ];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    final snapshot = await _firestore.getAnimals().first;
    _animals = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    setState(() {});
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Breeding Record'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                onChanged: (value) => setState(() => _selectedAnimalId = value),
                validator: (v) => v == null ? 'Select an animal' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedEventType = v!),
                decoration: const InputDecoration(labelText: 'Event Type'),
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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

    final record = {
      'animalId': _selectedAnimalId,
      'event_type': _selectedEventType,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'notes': _notesController.text,
    };

    // Perform the async work
    await _firestore.addBreedingRecord(record);

    // Auto‑notification for Expected Calving or Heat Detected
    if (_selectedEventType == 'Expected Calving' || _selectedEventType == 'Heat Detected') {
      final title = '$_selectedEventType Reminder';
      final message =
          'Selected cow has $_selectedEventType on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}';
      await _firestore.addNotification({
        'title': title,
        'message': message,
        'type': _selectedEventType.toLowerCase().replaceAll(' ', '_'),
        'is_read': false,
      });
    }

    if (mounted) Navigator.pop(context, record);
  }
}

// Set Reminder Dialog
class SetReminderDialog extends StatefulWidget {
  final String? animalName;
  final String? animalId;

  const SetReminderDialog({super.key, this.animalName, this.animalId});

  @override
  State<SetReminderDialog> createState() => _SetReminderDialogState();
}

class _SetReminderDialogState extends State<SetReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false; // ← guard flag

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.animalName != null
          ? 'Reminder for ${widget.animalName}'
          : 'Set General Reminder'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Reminder Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Reminder Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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

    final title = widget.animalName != null
        ? 'Reminder for ${widget.animalName}'
        : 'General Reminder';
    final message = _notesController.text.isNotEmpty
        ? _notesController.text
        : 'Reminder set for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}';

    await FirestoreService().addNotification({
      'title': title,
      'message': message,
      'type': widget.animalId != null ? 'animal_reminder' : 'general_reminder',
      'is_read': false,
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder set successfully')),
      );
    }
  }
}