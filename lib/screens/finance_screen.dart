// lib/screens/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';  // ✅ Added
import 'financial_report_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FirestoreService _firestore = FirestoreService();

  DateTime _selectedMonth = DateTime.now();
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netProfit = 0;
  Map<String, double> _expenseBreakdown = {};
  List<Map<String, dynamic>> _recentExpenses = [];
  List<Map<String, dynamic>> _recentIncomes = [];
  bool _isLoading = true;
  bool _isAddingExpense = false;
  bool _isAddingIncome = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    try {
      final results = await Future.wait([
        _firestore.getMilkSalesForMonth(startDate, endDate),
        _firestore.getOtherIncomeForMonth(startDate, endDate),
        _firestore.getOtherExpensesForMonth(startDate, endDate),
        _firestore.getFeedCostForMonth(startDate, endDate),
        _firestore.getVetCostForMonth(startDate, endDate),
        _firestore.getExpensesListForMonth(startDate, endDate),
        _firestore.getOtherIncomeListForMonth(startDate, endDate),
      ]);

      final milkSales = results[0] as double;
      final otherIncome = results[1] as double;
      final otherExpenses = results[2] as double;
      final feedCost = results[3] as double;
      final vetCost = results[4] as double;
      final expensesList = results[5] as List<Map<String, dynamic>>;
      final incomesList = results[6] as List<Map<String, dynamic>>;

      final totalIncome = milkSales + otherIncome;
      final totalExpense = feedCost + vetCost + otherExpenses;
      final netProfit = totalIncome - totalExpense;

      setState(() {
        _totalIncome = totalIncome;
        _totalExpense = totalExpense;
        _netProfit = netProfit;
        _expenseBreakdown = {
          'Feed': feedCost,
          'Vet': vetCost,
          'Other': otherExpenses,
        };
        _recentExpenses = expensesList;
        _recentIncomes = incomesList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addExpense() async {
    if (_isAddingExpense) return;
    _isAddingExpense = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );

    if (result != null) {
      await _firestore.addExpense(result);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added'), backgroundColor: AppColors.primary),
        );
      }
    }

    _isAddingExpense = false;
  }

  Future<void> _addOtherIncome() async {
    if (_isAddingIncome) return;
    _isAddingIncome = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddIncomeDialog(),
    );

    if (result != null) {
      await _firestore.addOtherIncome(result);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income added'), backgroundColor: AppColors.primary),
        );
      }
    }

    _isAddingIncome = false;
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteExpense(id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteIncome(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Income'),
        content: const Text('Are you sure you want to delete this income?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteOtherIncome(id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income deleted'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
      _loadData();
    });
  }

  String _formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

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
        title: const Text('Finance - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    _formatMonth(_selectedMonth),
                    style: const TextStyle(
                      fontSize: AppFontSizes.large,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Net Profit Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: _netProfit >= 0 ? AppColors.primary : Colors.red,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Net Profit',
                        style: TextStyle(color: Colors.white, fontSize: AppFontSizes.small),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Ksh ${_netProfit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSizes.huge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Income and Expense Row
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Income',
                        'Ksh ${_totalIncome.toStringAsFixed(0)}',
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildSummaryCard(
                        'Expense',
                        'Ksh ${_totalExpense.toStringAsFixed(0)}',
                        Icons.trending_down,
                        Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Expense Breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expense Breakdown',
                          style: TextStyle(
                            fontSize: AppFontSizes.medium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildBreakdownRow('Feed', _expenseBreakdown['Feed'] ?? 0),
                        _buildBreakdownRow('Veterinary', _expenseBreakdown['Vet'] ?? 0),
                        _buildBreakdownRow('Other Expenses', _expenseBreakdown['Other'] ?? 0),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Recent Transactions
                if (_recentExpenses.isNotEmpty || _recentIncomes.isNotEmpty) ...[
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: AppFontSizes.medium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._recentExpenses.map((expense) => _buildTransactionTile(
                    icon: Icons.money_off,
                    iconColor: Colors.red,
                    title: expense['category'] ?? 'Expense',
                    subtitle: expense['description'] ?? '',
                    amount: -expense['amount'],
                    date: expense['date'],
                    onDelete: () => _deleteExpense(expense['id']),
                  )),
                  ..._recentIncomes.map((income) => _buildTransactionTile(
                    icon: Icons.attach_money,
                    iconColor: Colors.green,
                    title: income['source'] ?? 'Income',
                    subtitle: income['description'] ?? '',
                    amount: income['amount'],
                    date: income['date'],
                    onDelete: () => _deleteIncome(income['id']),
                  )),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addExpense,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addOtherIncome,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Income'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FinancialReportScreen()),
                      );
                    },
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('View Full Report'),
                  ),
                ),
              ],
            ],
          ),
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
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppFontSizes.medium)),
          Text(title, style: const TextStyle(fontSize: AppFontSizes.small, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text('Ksh ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double amount,
    required String date,
    required VoidCallback onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title),
        subtitle: Text(subtitle.isNotEmpty ? subtitle : date),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${amount >= 0 ? '+' : ''}Ksh ${amount.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amount >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// Add Expense Dialog with guard (unchanged)
class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Feed';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _categories = [
    'Feed', 'Veterinary', 'Labor', 'Equipment', 'Transport', 'Rent', 'Other'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (String? v) => setState(() => _selectedCategory = v!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (Ksh)'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.md),
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
      'category': _selectedCategory,
      'amount': double.parse(_amountController.text),
      'description': _descriptionController.text,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}

// Add Income Dialog with guard (unchanged)
class AddIncomeDialog extends StatefulWidget {
  const AddIncomeDialog({super.key});

  @override
  State<AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<AddIncomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedSource = 'Calf Sales';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _sources = [
    'Calf Sales', 'Cow Sales', 'Manure Sales', 'Other'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Other Income'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSource,
              items: _sources.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
              onChanged: (String? v) => setState(() => _selectedSource = v!),
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (Ksh)'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.md),
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
      'source': _selectedSource,
      'amount': double.parse(_amountController.text),
      'description': _descriptionController.text,
      'date': _selectedDate.toIso8601String().split('T')[0],
    });
  }
}