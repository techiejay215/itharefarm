// lib/screens/add_animal_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for DateFormat

import '../config/colors.dart';
import '../services/firestore_service.dart';

class AddAnimalScreen extends StatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _earTagController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController(); // new

  String _selectedStatus = 'Lactating';
  String _selectedType = 'Cow';
  bool _isSaving = false;

  DateTime? _dateOfBirth; // new

  final List<String> _statusOptions = [
    'Lactating',
    'Pregnant',
    'Dry',
    'Calf',
    'Sold',
  ];

  final List<String> _typeOptions = [
    'Cow',
    'Bull',
    'Heifer',
  ];

  Future<void> _saveAnimal() async {
    // 🔒 Guard against double‑tap
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.addAnimal({
        'ear_tag': _earTagController.text.trim(),
        'breed': _breedController.text.trim(),
        'status': _selectedStatus,
        'name': _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        'animal_type': _selectedType,
        'last_calving': null,
        'mother_name': _motherNameController.text.trim().isEmpty
            ? null
            : _motherNameController.text.trim(), // new
        'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0], // new
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal added successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _earTagController.dispose();
    _breedController.dispose();
    _nameController.dispose();
    _motherNameController.dispose(); // new
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add New Animal'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name (Optional)
              const Text(
                'Name (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Daisy, Buttercup',
                  prefixIcon: Icon(Icons.edit),
                ),
              ),

              const SizedBox(height: 16),

              // Ear Tag
              const Text(
                'Ear Tag Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _earTagController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 145',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter ear tag number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Breed
              const Text(
                'Breed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Friesian, Ayrshire, Jersey',
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter breed';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Animal Type
              const Text(
                'Animal Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: _typeOptions.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Mother's name (Optional) – new
              const Text(
                'Mother\'s Name (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _motherNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Bessie',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),

              const SizedBox(height: 16),

              // Date of Birth (Optional) – new
              const Text(
                'Date of Birth (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _dateOfBirth = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dateOfBirth == null
                            ? 'Select date'
                            : DateFormat('MMM dd, yyyy').format(_dateOfBirth!),
                        style: TextStyle(
                          color: _dateOfBirth == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save button – disable when saving
              ElevatedButton(
                onPressed: _isSaving ? null : _saveAnimal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Save Animal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}