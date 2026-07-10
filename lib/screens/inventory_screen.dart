// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../widgets/set_reminder_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  // Guard flags for parent methods
  bool _isAddingInventory = false;
  bool _isEditingInventory = false;
  bool _isRecordingUsage = false;
  bool _isRestocking = false;

  final List<String> _categories = ['All', 'Medicine', 'Equipment'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final medicines = await _firestore.getMedicineInventory();
      final equipment = await _firestore.getEquipmentInventory();
      final lowStock = await _firestore.getLowMedicineStock();
      setState(() {
        _medicines = medicines;
        _equipment = equipment;
        _lowStockItems = lowStock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading inventory: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addInventoryItem() async {
    if (_isAddingInventory) return;
    _isAddingInventory = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddInventoryItemDialog(),
    );
    if (result != null) {
      await _firestore.addInventoryItem(result);
      _loadData();
      _showSnackBar('Item added');
    }

    _isAddingInventory = false;
  }

  Future<void> _editInventoryItem(Map<String, dynamic> item) async {
    if (_isEditingInventory) return;
    _isEditingInventory = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditInventoryItemDialog(item: item),
    );
    if (result != null) {
      await _firestore.updateInventoryItem(result['id'], result);
      _loadData();
      _showSnackBar('Item updated');
    }

    _isEditingInventory = false;
  }

  Future<void> _deleteInventoryItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
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
      await _firestore.deleteInventoryItem(item['id']);
      _loadData();
      _showSnackBar('Item deleted');
    }
  }

  Future<void> _recordUsage(Map<String, dynamic> item) async {
    if (_isRecordingUsage) return;
    _isRecordingUsage = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RecordUsageDialog(item: item),
    );
    if (result != null) {
      await _firestore.updateInventoryQuantity(result['id'], result['newQuantity']);
      final updatedItem = await _firestore.getInventoryItem(result['id']);
      if (updatedItem != null && updatedItem['quantity'] <= updatedItem['min_threshold']) {
        await _firestore.addNotification({
          'title': 'Low Stock Alert',
          'message': '${updatedItem['name']} is low (${updatedItem['quantity']} ${updatedItem['unit']} remaining)',
          'type': 'low_stock',
          'is_read': false,
        });
      }
      _loadData();
      _showSnackBar('Usage recorded');
    }

    _isRecordingUsage = false;
  }

  Future<void> _restockItem(Map<String, dynamic> item) async {
    if (_isRestocking) return;
    _isRestocking = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RestockDialog(item: item),
    );
    if (result != null) {
      await _firestore.updateInventoryQuantity(result['id'], result['newQuantity']);
      await _firestore.addInventoryPurchase(result);
      final updatedItem = await _firestore.getInventoryItem(result['id']);
      if (updatedItem != null && updatedItem['quantity'] <= updatedItem['min_threshold']) {
        await _firestore.addNotification({
          'title': 'Low Stock Alert',
          'message': '${updatedItem['name']} is low (${updatedItem['quantity']} ${updatedItem['unit']} remaining)',
          'type': 'low_stock',
          'is_read': false,
        });
      }
      _loadData();
      _showSnackBar('Restock recorded');
    }

    _isRestocking = false;
  }

  void _showSetReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => const SetReminderDialog(animalName: null, animalId: null),
    ).then((_) => _loadData());
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory - Ithare Farm'),
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
          : SafeArea(
              child: Column(
                children: [
                  // Search Field
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search inventory...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        // TODO: implement filtering if needed
                      },
                    ),
                  ),
                  // Category Filter
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                            },
                            backgroundColor: AppColors.background,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.white : AppColors.textDark,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Low Stock Section (if any)
                  if (_lowStockItems.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '⚠️ Low Stock Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _lowStockItems.length,
                        itemBuilder: (context, index) {
                          final item = _lowStockItems[index];
                          return Container(
                            width: 280,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item['type'] == 'Medicine' ? Icons.medication : Icons.build,
                                      color: AppColors.amber,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(item['quantity'] as double).toStringAsFixed(0)} ${item['unit']} remaining',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  'Min: ${(item['min_threshold'] as double).toStringAsFixed(0)} ${item['unit']}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _restockItem(item),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        child: const Text('Restock', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // Main List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                      itemCount: _selectedCategory == 'All'
                          ? _medicines.length + _equipment.length
                          : _selectedCategory == 'Medicine'
                              ? _medicines.length
                              : _equipment.length,
                      itemBuilder: (context, index) {
                        if (_selectedCategory == 'All') {
                          if (index < _medicines.length) {
                            return _buildInventoryCard(_medicines[index]);
                          } else {
                            return _buildInventoryCard(
                                _equipment[index - _medicines.length]);
                          }
                        } else if (_selectedCategory == 'Medicine') {
                          return _buildInventoryCard(_medicines[index]);
                        } else {
                          return _buildInventoryCard(_equipment[index]);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory_fab',
        onPressed: _addInventoryItem,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  // ---------- INVENTORY CARD WITH EDIT/DELETE ----------
  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final isLowStock = item['quantity'] <= item['min_threshold'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Row: Icon + Item Name ---
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item['type'] == 'Medicine'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['type'] == 'Medicine' ? Icons.medication : Icons.build,
                    color: item['type'] == 'Medicine' ? Colors.blue : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Quantity ---
            Text(
              '${(item['quantity'] as double).toStringAsFixed(0)} ${item['unit']} remaining',
              style: const TextStyle(fontSize: 14),
            ),

            // --- Expiry ---
            if (item['expiry_date'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Expires: ${_formatDate(item['expiry_date'])}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],

            // --- Low Stock Warning ---
            if (isLowStock) ...[
              const SizedBox(height: 4),
              Text(
                'Min: ${(item['min_threshold'] as double).toStringAsFixed(0)} ${item['unit']}',
                style: const TextStyle(fontSize: 12, color: AppColors.amber),
              ),
            ],

            const SizedBox(height: 8),

            // --- Row: Action Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editInventoryItem(item),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deleteInventoryItem(item),
                  tooltip: 'Delete',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20),
                  onPressed: () => _recordUsage(item),
                  tooltip: 'Record Usage',
                ),
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  onPressed: () => _restockItem(item),
                  tooltip: 'Restock',
                ),
              ],
            ),
          ],
        ),
      ),
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
}

// ---------- DIALOGS ----------

class AddInventoryItemDialog extends StatefulWidget {
  const AddInventoryItemDialog({super.key});
  @override
  State<AddInventoryItemDialog> createState() => _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<AddInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _supplierController = TextEditingController();
  String _selectedType = 'Medicine';
  DateTime? _expiryDate;
  bool _isSaving = false;

  final List<String> _types = ['Medicine', 'Equipment'];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Inventory Item'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit (bottles, tubes, pairs, pieces)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum Stock Alert'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              if (_selectedType == 'Medicine')
                ListTile(
                  title: const Text('Expiry Date'),
                  subtitle: _expiryDate == null
                      ? const Text('Not set')
                      : Text(DateFormat('MMM dd, yyyy').format(_expiryDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier (optional)'),
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

    Navigator.pop(context, {
      'name': _nameController.text,
      'type': _selectedType,
      'quantity': double.parse(_quantityController.text),
      'unit': _unitController.text,
      'min_threshold': double.parse(_thresholdController.text),
      'expiry_date': _expiryDate?.toIso8601String().split('T')[0],
      'supplier': _supplierController.text.isEmpty ? null : _supplierController.text,
    });
  }
}

class EditInventoryItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditInventoryItemDialog({super.key, required this.item});

  @override
  State<EditInventoryItemDialog> createState() => _EditInventoryItemDialogState();
}

class _EditInventoryItemDialogState extends State<EditInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _thresholdController;
  late TextEditingController _supplierController;
  late String _selectedType;
  DateTime? _expiryDate;
  bool _isSaving = false;

  final List<String> _types = ['Medicine', 'Equipment'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item['name']);
    _unitController = TextEditingController(text: item['unit']);
    _thresholdController = TextEditingController(text: (item['min_threshold'] as double).toString());
    _supplierController = TextEditingController(text: item['supplier'] ?? '');
    _selectedType = item['type'] ?? 'Medicine';
    if (item['expiry_date'] != null) {
      _expiryDate = DateTime.tryParse(item['expiry_date']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Inventory Item'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum Stock Alert'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              if (_selectedType == 'Medicine')
                ListTile(
                  title: const Text('Expiry Date'),
                  subtitle: _expiryDate == null
                      ? const Text('Not set')
                      : Text(DateFormat('MMM dd, yyyy').format(_expiryDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier (optional)'),
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

    Navigator.pop(context, {
      'id': widget.item['id'],
      'name': _nameController.text,
      'type': _selectedType,
      'unit': _unitController.text,
      'min_threshold': double.parse(_thresholdController.text),
      'expiry_date': _expiryDate?.toIso8601String().split('T')[0],
      'supplier': _supplierController.text.isEmpty ? null : _supplierController.text,
    });
  }
}

class RecordUsageDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const RecordUsageDialog({super.key, required this.item});

  @override
  State<RecordUsageDialog> createState() => _RecordUsageDialogState();
}

class _RecordUsageDialogState extends State<RecordUsageDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedAnimalId;
  List<Map<String, dynamic>> _animals = [];
  bool _isSaving = false;

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
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Usage'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.item['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity used (${widget.item['unit']})'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedAnimalId,
                isExpanded: true,
                hint: const Text('Used on (optional)'),
                items: _animals.map<DropdownMenuItem<String>>((animal) {
                  return DropdownMenuItem<String>(
                    value: animal['id'],
                    child: Text('Cow #${animal['ear_tag']} - ${animal['breed']}'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedAnimalId = v),
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

    final newQuantity = (widget.item['quantity'] as double) - double.parse(_quantityController.text);
    Navigator.pop(context, {
      'id': widget.item['id'],
      'newQuantity': newQuantity < 0 ? 0 : newQuantity,
      'quantity_used': double.parse(_quantityController.text),
      'animal_id': _selectedAnimalId,
      'notes': _notesController.text,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}

class RestockDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const RestockDialog({super.key, required this.item});

  @override
  State<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restock Item'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.item['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Current stock: ${(widget.item['quantity'] as double).toStringAsFixed(0)} ${widget.item['unit']}',
                style: const TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity to add (${widget.item['unit']})'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              if (widget.item['type'] == 'Medicine')
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Cost (Ksh)'),
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

    final newQuantity = (widget.item['quantity'] as double) + double.parse(_quantityController.text);
    Navigator.pop(context, {
      'id': widget.item['id'],
      'newQuantity': newQuantity,
      'quantity_added': double.parse(_quantityController.text),
      'cost': double.tryParse(_costController.text) ?? 0,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}