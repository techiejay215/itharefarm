// lib/screens/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';  // ✅ Added

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<Map<String, dynamic>> _todaySales = [];
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic> _todaySummary = {};
  bool _isLoading = true;

  bool _isAddingSale = false;
  bool _isAddingCustomer = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final todaySales = await _firestore.getTodaySalesWithCustomers();
    final customers = await _firestore.getAllCustomers();
    final summary = await _firestore.getTodaySalesSummary();

    setState(() {
      _todaySales = todaySales;
      _customers = customers;
      _todaySummary = summary;
      _isLoading = false;
    });
  }

  Future<void> _addSale() async {
    if (_isAddingSale) return;
    _isAddingSale = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddSaleDialog(),
    );
    if (result != null) {
      await _firestore.addSale(result);
      String customerName = 'Unknown';
      if (result['customerId'] != null) {
        final customerDoc = await _firestore.getDocument('customers', result['customerId']);
        if (customerDoc.exists) {
          final customerData = customerDoc.data() as Map<String, dynamic>;
          customerName = customerData['name'] ?? 'Unknown';
        }
      }
      await _firestore.addNotification({
        'title': 'Sale Recorded',
        'message': 'Sale to $customerName: ${(result['quantity'] as double).toStringAsFixed(0)}L, Ksh ${(result['total'] as double).toStringAsFixed(0)}',
        'type': 'payment',
        'is_read': false,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }

    _isAddingSale = false;
  }

  Future<void> _addCustomer() async {
    if (_isAddingCustomer) return;
    _isAddingCustomer = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
    if (result != null) {
      await _firestore.addCustomer(result);
      await _firestore.addNotification({
        'title': 'New Customer Added',
        'message': 'Customer "${result['name']}" added',
        'type': 'customer',
        'is_read': false,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer added'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }

    _isAddingCustomer = false;
  }

  void _viewCustomer(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CustomerProfileSheet(customer: customer),
    );
  }

  String _formatCurrency(double amount) =>
      'Ksh ${amount.toStringAsFixed(0)}';

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
        title: const Text('Milk Sales - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  _buildQuickEntryCard(),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _addCustomer,
                    child: const Text('+ Add New Customer'),
                  ),
                  const SizedBox(height: 24),
                  _buildTodaySalesList(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All Sales'),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'sales_fab',
        onPressed: _addSale,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Today's Sales Summary",
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '🥛',
                  '${(_todaySummary['total_litres'] ?? 0).toStringAsFixed(0)} L',
                  'Litres',
                ),
                _buildSummaryItem(
                  '💰',
                  _formatCurrency(_todaySummary['total_revenue'] ?? 0),
                  'Revenue',
                ),
                _buildSummaryItem(
                  '📊',
                  'Ksh ${(_todaySummary['avg_price'] ?? 0).toStringAsFixed(0)}/L',
                  'Avg Price',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildQuickEntryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _customers.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No customers yet.'),
                ),
              )
            : Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    hint: const Text('Select Customer'),
                    items: _customers.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(
                          '${c['name']} - Ksh ${(c['default_price'] as double).toStringAsFixed(0)}/L',
                        ),
                      );
                    }).toList(),
                    onChanged: (_) {},
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addSale,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Record Sale'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTodaySalesList() {
    if (_todaySales.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No sales recorded today'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Sales List",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ..._todaySales.map(
          (sale) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sale['payment_status'] == 'Paid'
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sale['payment_status'] == 'Paid'
                      ? Icons.check
                      : Icons.pending,
                  size: 20,
                  color: sale['payment_status'] == 'Paid'
                      ? AppColors.primary
                      : AppColors.amber,
                ),
              ),
              title: Text(sale['customer_name']),
              subtitle: Text(
                '${(sale['quantity'] as double).toStringAsFixed(0)}L @ Ksh ${(sale['price_per_litre'] as double).toStringAsFixed(0)}/L',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(sale['total']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sale['payment_status'] == 'Paid'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sale['payment_status'],
                      style: TextStyle(
                        fontSize: 10,
                        color: sale['payment_status'] == 'Paid'
                            ? AppColors.primary
                            : AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => _viewCustomer(sale),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- Dialogs --------------------

// Add Sale Dialog (unchanged)
class AddSaleDialog extends StatefulWidget {
  const AddSaleDialog({super.key});

  @override
  State<AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends State<AddSaleDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  String? _selectedCustomerId;
  double _pricePerLitre = 0;
  double _total = 0;
  String _paymentStatus = 'Paid';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _customers = [];
  bool _isSaving = false;

  final List<String> _paymentStatuses = ['Paid', 'Pending', 'Partial'];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _quantityController.addListener(_calculateTotal);
  }

  Future<void> _loadCustomers() async {
    _customers = await _firestore.getAllCustomers();
    setState(() {});
  }

  void _calculateTotal() {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    _total = qty * _pricePerLitre;
    setState(() {});
  }

  @override
  void dispose() {
    _quantityController.removeListener(_calculateTotal);
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Sale'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              isExpanded: true,
              hint: const Text('Select Customer'),
              items: _customers.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem<String>(
                  value: c['id'],
                  child: Text(
                    '${c['name']} - Ksh ${(c['default_price'] as double).toStringAsFixed(0)}/L',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                _selectedCustomerId = value;
                if (value != null) {
                  final customer =
                      _customers.firstWhere((c) => c['id'] == value);
                  _pricePerLitre = customer['default_price'] as double;
                  _calculateTotal();
                }
                setState(() {});
              },
              validator: (v) => v == null ? 'Select a customer' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (Litres)',
                suffixText: 'L',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter quantity' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _pricePerLitre.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price per Litre (Ksh)',
                prefixText: 'Ksh ',
              ),
              onChanged: (value) {
                _pricePerLitre = double.tryParse(value ?? '0') ?? 0;
                _calculateTotal();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:'),
                  Text(
                    'Ksh ${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              items: _paymentStatuses.map<DropdownMenuItem<String>>((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (v) {
                _paymentStatus = v!;
                setState(() {});
              },
              decoration: const InputDecoration(labelText: 'Payment Status'),
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
                if (date != null) {
                  _selectedDate = date;
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'customerId': _selectedCustomerId,
      'quantity': double.parse(_quantityController.text),
      'price_per_litre': _pricePerLitre,
      'total': _total,
      'payment_status': _paymentStatus,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}

// Add Customer Dialog (unchanged)
class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Customer'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default Price per Litre (Ksh)',
                prefixText: 'Ksh ',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'default_price': double.parse(_priceController.text.trim()),
    });
  }
}

// Customer Profile Bottom Sheet (unchanged)
class CustomerProfileSheet extends StatelessWidget {
  final Map<String, dynamic> customer;

  const CustomerProfileSheet({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['customer_name'] ?? customer['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Price: Ksh ${(customer['default_price'] ?? customer['price_per_litre'] ?? 0).toStringAsFixed(0)}/L',
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Recent Sales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Sale history will appear here'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Record Payment'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history),
              label: const Text('View All Transactions'),
            ),
          ),
        ],
      ),
    );
  }
}