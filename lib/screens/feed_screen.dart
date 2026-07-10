// lib/screens/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../widgets/set_reminder_dialog.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<Map<String, dynamic>> _feedInventory = [];
  List<Map<String, dynamic>> _todayUsage = [];
  double _monthlyCost = 0;
  List<Map<String, dynamic>> _lowStockItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await _firestore.getFeedInventory();
      final todayUsage = await _firestore.getTodayFeedUsage();
      final monthlyCost = await _firestore.getMonthlyFeedCost();
      final lowStock = await _firestore.getLowStockItems();
      setState(() {
        _feedInventory = inventory;
        _todayUsage = todayUsage;
        _monthlyCost = monthlyCost;
        _lowStockItems = lowStock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feed data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ---------- Add Purchase ----------
  Future<void> _addFeedPurchase() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddFeedPurchaseDialog(),
    );

    if (result != null) {
      await _firestore.addFeedPurchase(result);
      final feedName = result['feed_name'];
      final quantity = result['quantity'] as double;
      final unit = result['unit'];
      final threshold = result['min_threshold'] as double;

      final existing = await _firestore.getFeedItem(feedName);
      if (existing != null) {
        final newQty = (existing['quantity'] as double) + quantity;
        await _firestore.updateFeedQuantity(feedName, newQty);
      } else {
        await _firestore.addFeedItem({
          'name': feedName,
          'quantity': quantity,
          'unit': unit,
          'min_threshold': threshold,
        });
      }
      // Low stock check
      final updated = await _firestore.getFeedItem(feedName);
      if (updated != null && updated['quantity'] <= updated['min_threshold']) {
        await _firestore.addNotification({
          'title': 'Low Feed Alert',
          'message': '$feedName is low (${updated['quantity']} ${updated['unit']} remaining)',
          'type': 'low_stock',
          'is_read': false,
        });
      }
      _loadData();
      _showSnackBar('Feed purchase recorded');
    }
  }

  // ---------- Record Usage ----------
  Future<void> _recordDailyUsage() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const RecordFeedUsageDialog(),
    );
    if (result != null) {
      await _firestore.addFeedUsage(result);
      final feedName = result['feed_name'];
      final quantity = result['quantity'] as double;

      final existing = await _firestore.getFeedItem(feedName);
      if (existing != null) {
        final newQty = (existing['quantity'] as double) - quantity;
        await _firestore.updateFeedQuantity(feedName, newQty);
        final updated = await _firestore.getFeedItem(feedName);
        if (updated != null && updated['quantity'] <= updated['min_threshold']) {
          await _firestore.addNotification({
            'title': 'Low Feed Alert',
            'message': '$feedName is low (${updated['quantity']} ${updated['unit']} remaining)',
            'type': 'low_stock',
            'is_read': false,
          });
        }
      } else {
        _showSnackBar('Error: Feed not found in inventory.', isError: true);
        _loadData();
        return;
      }
      _loadData();
      _showSnackBar('Feed usage recorded');
    }
  }

  // ---------- Edit Feed Item ----------
  Future<void> _editFeedItem(Map<String, dynamic> feed) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditFeedItemDialog(feed: feed),
    );
    if (result != null) {
      await _firestore.updateFeedItem(result['id'], result);
      _loadData();
      _showSnackBar('Feed item updated');
    }
  }

  // ---------- Delete Feed Item ----------
  Future<void> _deleteFeedItem(Map<String, dynamic> feed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Feed Item'),
        content: Text('Are you sure you want to delete "${feed['name']}"?'),
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
      await _firestore.deleteFeedItem(feed['id']);
      _loadData();
      _showSnackBar('Feed item deleted');
    }
  }

  // ---------- Reminder ----------
  void _showSetReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => const SetReminderDialog(animalName: null, animalId: null),
    ).then((_) => _loadData());
  }

  bool _isLowStock(double quantity, double threshold) => quantity <= threshold;

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feed Management - Ithare Farm'),
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
                  // ----- Stock Summary Grid -----
                  const Text(
                    'Feed Stock Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _feedInventory.length,
                    itemBuilder: (context, index) {
                      final feed = _feedInventory[index];
                      final isLow = _isLowStock(
                        feed['quantity'] as double,
                        feed['min_threshold'] as double,
                      );
                      return _buildFeedCard(
                        feed: feed,
                        isLow: isLow,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ----- Today's Usage -----
                  const Text(
                    "Today's Feed Usage",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _todayUsage.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No usage recorded today')))
                          : Column(
                              children: _todayUsage.map((usage) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(usage['feed_name']),
                                    Text(
                                      '${(usage['quantity'] as double).toStringAsFixed(0)} ${usage['unit']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----- Cost Summary -----
                  const Text(
                    'Cost Summary - This Month',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Feed Cost', style: TextStyle(fontSize: 14)),
                          Text(
                            'Ksh ${_monthlyCost.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----- Low Stock Alerts -----
                  if (_lowStockItems.isNotEmpty) ...[
                    const Text(
                      '⚠️ Low Stock Alerts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.amber),
                    ),
                    const SizedBox(height: 12),
                    ..._lowStockItems.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: AppColors.amber.withOpacity(0.1),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber, color: AppColors.amber),
                        title: Text(item['name']),
                        subtitle: Text(
                          '${(item['quantity'] as double).toStringAsFixed(0)} ${item['unit']} remaining (Min: ${(item['min_threshold'] as double).toStringAsFixed(0)} ${item['unit']})',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // ----- Action Buttons -----
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addFeedPurchase,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Purchase'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recordDailyUsage,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Record Usage'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- Feed Card ----------
  Widget _buildFeedCard({
    required Map<String, dynamic> feed,
    required bool isLow,
  }) {
    final name = feed['name'];
    final quantity = feed['quantity'] as double;
    final unit = feed['unit'];
    final id = feed['id'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isLow ? Border.all(color: AppColors.amber, width: 1) : null,
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _getFeedIcon(name),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                    onPressed: () => _editFeedItem(feed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    onPressed: () => _deleteFeedItem(feed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            '${quantity.toStringAsFixed(0)} $unit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isLow ? AppColors.amber : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isLow ? '⚠️ Low Stock' : 'In Stock',
            style: TextStyle(fontSize: 11, color: isLow ? AppColors.amber : AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _getFeedIcon(String name) {
    if (name.contains('Dairy')) {
      return const Icon(Icons.grass, size: 24, color: AppColors.primary);
    } else if (name.contains('Hay')) {
      return const Icon(Icons.forest, size: 24, color: AppColors.primary);
    } else if (name.contains('Silage')) {
      return const Icon(Icons.inventory, size: 24, color: AppColors.primary);
    } else if (name.contains('Mineral')) {
      return const Icon(Icons.medication, size: 24, color: AppColors.primary);
    }
    return const Icon(Icons.restaurant, size: 24, color: AppColors.primary);
  }
}

// ===================================================================
// DIALOGS (with save-guard pattern)
// ===================================================================

// ---------- ADD FEED PURCHASE DIALOG ----------
class AddFeedPurchaseDialog extends StatefulWidget {
  const AddFeedPurchaseDialog({super.key});

  @override
  State<AddFeedPurchaseDialog> createState() => _AddFeedPurchaseDialogState();
}

class _AddFeedPurchaseDialogState extends State<AddFeedPurchaseDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _unitController = TextEditingController();
  final _thresholdController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isNewFeed = true;
  List<Map<String, dynamic>> _existingFeeds = [];
  String? _selectedFeedName;
  bool _isSaving = false;   // ← new flag

  @override
  void initState() {
    super.initState();
    _loadExistingFeeds();
  }

  Future<void> _loadExistingFeeds() async {
    final feeds = await _firestore.getFeedInventory();
    setState(() => _existingFeeds = feeds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Feed Purchase'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Select existing or new?'),
                    const SizedBox(width: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Existing')),
                        ButtonSegment(value: false, label: Text('New')),
                      ],
                      selected: {_isNewFeed},
                      onSelectionChanged: (set) => setState(() => _isNewFeed = set.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isNewFeed) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Feed Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unit (kg, bales, tons, bags)'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minimum Stock Alert'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedFeedName,
                    isExpanded: true,
                    hint: const Text('Select Feed'),
                    items: _existingFeeds.map<DropdownMenuItem<String>>((feed) {
                      return DropdownMenuItem<String>(
                        value: feed['name'],
                        child: Text('${feed['name']} (${feed['unit']})'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedFeedName = v),
                    validator: (v) => v == null ? 'Select a feed' : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Cost (Ksh)'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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

    String feedName, unit;
    double threshold;
    if (_isNewFeed) {
      feedName = _nameController.text;
      unit = _unitController.text;
      threshold = double.parse(_thresholdController.text);
    } else {
      final selected = _existingFeeds.firstWhere((f) => f['name'] == _selectedFeedName);
      feedName = selected['name'];
      unit = selected['unit'];
      threshold = selected['min_threshold'] as double;
    }

    Navigator.pop(context, {
      'feed_name': feedName,
      'quantity': double.parse(_quantityController.text),
      'unit': unit,
      'cost': double.parse(_costController.text),
      'date': _selectedDate.toIso8601String().split('T')[0],
      'min_threshold': threshold,
    });
  }
}

// ---------- RECORD FEED USAGE DIALOG ----------
class RecordFeedUsageDialog extends StatefulWidget {
  const RecordFeedUsageDialog({super.key});

  @override
  State<RecordFeedUsageDialog> createState() => _RecordFeedUsageDialogState();
}

class _RecordFeedUsageDialogState extends State<RecordFeedUsageDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  String? _selectedFeedName;
  String _selectedUnit = 'kg';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _feeds = [];
  bool _isSaving = false;   // ← new flag

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    final feeds = await _firestore.getFeedInventory();
    setState(() => _feeds = feeds);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Daily Usage'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedFeedName,
                isExpanded: true,
                hint: const Text('Select Feed'),
                items: _feeds.map<DropdownMenuItem<String>>((feed) {
                  return DropdownMenuItem<String>(
                    value: feed['name'],
                    child: Text('${feed['name']} (${feed['unit']})'),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedFeedName = v;
                    final feed = _feeds.firstWhere((f) => f['name'] == v);
                    _selectedUnit = feed['unit'];
                  });
                },
                validator: (v) => v == null ? 'Select a feed' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity ($_selectedUnit)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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

    Navigator.pop(context, {
      'feed_name': _selectedFeedName,
      'quantity': double.parse(_quantityController.text),
      'unit': _selectedUnit,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}

// ---------- EDIT FEED ITEM DIALOG ----------
class EditFeedItemDialog extends StatefulWidget {
  final Map<String, dynamic> feed;
  const EditFeedItemDialog({super.key, required this.feed});

  @override
  State<EditFeedItemDialog> createState() => _EditFeedItemDialogState();
}

class _EditFeedItemDialogState extends State<EditFeedItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _thresholdController;
  bool _isSaving = false;   // ← new flag

  @override
  void initState() {
    super.initState();
    final feed = widget.feed;
    _nameController = TextEditingController(text: feed['name']);
    _unitController = TextEditingController(text: feed['unit']);
    _thresholdController = TextEditingController(
      text: (feed['min_threshold'] as double).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Feed Item'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Feed Name'),
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
              Text(
                'Current quantity: ${(widget.feed['quantity'] as double).toStringAsFixed(0)} ${widget.feed['unit']}',
                style: const TextStyle(color: AppColors.textLight),
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
      'id': widget.feed['id'],
      'name': _nameController.text,
      'unit': _unitController.text,
      'min_threshold': double.parse(_thresholdController.text),
    });
  }
}