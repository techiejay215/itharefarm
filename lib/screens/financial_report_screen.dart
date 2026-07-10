// lib/screens/financial_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../config/colors.dart';
import '../services/role_service.dart';  // ✅ Added

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final FirestoreService _firestore = FirestoreService();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  String _selectedPeriod = 'monthly';

  List<Map<String, dynamic>> _monthlyTrend = [];

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentAmber = Color(0xFFF9A825);
  static const Color backgroundGray = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF424242);
  static const Color textLight = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    DateTime startDate;
    DateTime endDate;
    switch (_selectedPeriod) {
      case 'weekly':
        final weekday = _selectedDate.weekday;
        final daysToSubtract = weekday - 1;
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day - daysToSubtract);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case 'monthly':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case 'quarterly':
        final quarter = ((_selectedDate.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        startDate = DateTime(_selectedDate.year, startMonth, 1);
        endDate = DateTime(_selectedDate.year, startMonth + 3, 0);
        break;
      case 'yearly':
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31);
        break;
      default:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    }

    try {
      final results = await Future.wait([
        _firestore.getMilkSalesForMonth(startDate, endDate),
        _firestore.getOtherIncomeForMonth(startDate, endDate),
        _firestore.getFeedCostForMonth(startDate, endDate),
        _firestore.getVetCostForMonth(startDate, endDate),
        _firestore.getLaborCostForMonth(startDate, endDate),
        _firestore.getEquipmentCostForMonth(startDate, endDate),
        _firestore.getOtherExpensesForMonth(startDate, endDate),
        _firestore.getYearlyProfitTrend(12),
      ]);

      final milkSales = results[0] as double;
      final otherIncome = results[1] as double;
      final feedCost = results[2] as double;
      final vetCost = results[3] as double;
      final laborCost = results[4] as double;
      final equipmentCost = results[5] as double;
      final otherExpenses = results[6] as double;
      final trend = results[7] as List<Map<String, dynamic>>;

      final totalIncome = milkSales + otherIncome;
      final totalExpense = feedCost + vetCost + laborCost + equipmentCost + otherExpenses;
      final netProfit = totalIncome - totalExpense;
      final profitMargin = totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0;

      if (!mounted) return;
      setState(() {
        _reportData = {
          'start_date': startDate,
          'end_date': endDate,
          'total_income': totalIncome,
          'total_expense': totalExpense,
          'net_profit': netProfit,
          'profit_margin': profitMargin,
          'milk_sales': milkSales,
          'other_income': otherIncome,
          'feed_cost': feedCost,
          'vet_cost': vetCost,
          'labor_cost': laborCost,
          'equipment_cost': equipmentCost,
          'other_expenses': otherExpenses,
        };
        _monthlyTrend = trend;
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

  void _changePeriod(int offset) {
    setState(() {
      switch (_selectedPeriod) {
        case 'weekly':
          _selectedDate = _selectedDate.add(Duration(days: offset * 7));
          break;
        case 'monthly':
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
          break;
        case 'quarterly':
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + (offset * 3), 1);
          break;
        case 'yearly':
          _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
          break;
      }
      _loadData();
    });
  }

  String _formatPeriod() {
    switch (_selectedPeriod) {
      case 'weekly':
        final start = _reportData['start_date'] as DateTime?;
        final end = _reportData['end_date'] as DateTime?;
        if (start == null || end == null) return 'Loading...';
        return '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}';
      case 'monthly':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'quarterly':
        final quarter = ((_selectedDate.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${_selectedDate.year}';
      case 'yearly':
        return _selectedDate.year.toString();
      default:
        return DateFormat('MMMM yyyy').format(_selectedDate);
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_KE', symbol: 'Ksh ');
    return formatter.format(amount);
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export to PDF coming soon'), backgroundColor: primaryGreen),
    );
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
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: const Text('Financial Report', style: TextStyle(color: textDark)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryGreen),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: primaryGreen),
            onPressed: _exportReport,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildPeriodSelector(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildNetProfitCard(),
                    const SizedBox(height: 16),
                    _buildIncomeExpenseRow(),
                    const SizedBox(height: 24),
                    _buildIncomeBreakdown(),
                    const SizedBox(height: 16),
                    _buildExpenseBreakdown(),
                    const SizedBox(height: 16),
                    _buildComparisonChart(),
                    const SizedBox(height: 16),
                    _buildProfitTrendChart(),
                    const SizedBox(height: 16),
                    _buildMonthlyTrend(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'finance_fab',
        onPressed: () => _showAddTransactionDialog(),
        backgroundColor: primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------- UI Components ----------

  Widget _buildPeriodSelector() {
    final periods = [
      {'label': 'Weekly', 'value': 'weekly'},
      {'label': 'Monthly', 'value': 'monthly'},
      {'label': 'Quarterly', 'value': 'quarterly'},
      {'label': 'Yearly', 'value': 'yearly'},
    ];
    return Container(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              decoration: BoxDecoration(
                color: backgroundGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: periods.map((p) => _buildPeriodButton(p['label']!, p['value']!)).toList(),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changePeriod(-1),
                ),
                Text(
                  _formatPeriod(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changePeriod(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _loadData();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textLight,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNetProfitCard() {
    final isProfit = (_reportData['net_profit'] ?? 0) >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isProfit ? primaryGreen : Colors.red,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Net Profit',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency((_reportData['net_profit'] ?? 0).toDouble()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Margin: ${(_reportData['profit_margin'] ?? 0).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Income',
            _formatCurrency((_reportData['total_income'] ?? 0).toDouble()),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Expense',
            _formatCurrency((_reportData['total_expense'] ?? 0).toDouble()),
            Icons.trending_down,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeBreakdown() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.attach_money, color: primaryGreen),
                SizedBox(width: 8),
                Text(
                  'Income Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBreakdownRow(
              'Milk Sales',
              (_reportData['milk_sales'] ?? 0).toDouble(),
              (_reportData['total_income'] ?? 0).toDouble(),
              Icons.emoji_emotions,
            ),
            const Divider(),
            _buildBreakdownRow(
              'Other Income',
              (_reportData['other_income'] ?? 0).toDouble(),
              (_reportData['total_income'] ?? 0).toDouble(),
              Icons.attach_money,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseBreakdown() {
    final expenses = [
      {'label': 'Feed Cost', 'value': (_reportData['feed_cost'] ?? 0).toDouble(), 'icon': Icons.grass},
      {'label': 'Veterinary', 'value': (_reportData['vet_cost'] ?? 0).toDouble(), 'icon': Icons.health_and_safety},
      {'label': 'Labor', 'value': (_reportData['labor_cost'] ?? 0).toDouble(), 'icon': Icons.people},
      {'label': 'Equipment', 'value': (_reportData['equipment_cost'] ?? 0).toDouble(), 'icon': Icons.build},
      {'label': 'Other Expenses', 'value': (_reportData['other_expenses'] ?? 0).toDouble(), 'icon': Icons.more_horiz},
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_down, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Expense Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...expenses.map((expense) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBreakdownRow(
                expense['label'] as String,
                expense['value'] as double,
                (_reportData['total_expense'] ?? 0).toDouble(),
                expense['icon'] as IconData,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, double total, IconData icon) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: textLight),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: textLight)),
              ],
            ),
            Text(
              _formatCurrency(amount),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: backgroundGray,
          color: primaryGreen,
          borderRadius: BorderRadius.circular(4),
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 10, color: textLight),
        ),
      ],
    );
  }

  Widget _buildComparisonChart() {
    final total = (_reportData['total_income'] ?? 0) + (_reportData['total_expense'] ?? 0);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income vs Expense',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonBar(
              'Income',
              (_reportData['total_income'] ?? 0).toDouble(),
              total.toDouble(),
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildComparisonBar(
              'Expense',
              (_reportData['total_expense'] ?? 0).toDouble(),
              total.toDouble(),
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBar(String label, double value, double maxValue, Color color) {
    final percentage = maxValue > 0 ? (value / maxValue) * 100 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(_formatCurrency(value), style: TextStyle(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: backgroundGray,
            color: color,
            minHeight: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildProfitTrendChart() {
    if (_monthlyTrend.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No data available for chart')),
        ),
      );
    }

    final spots = _monthlyTrend.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return FlSpot(index.toDouble(), (data['profit'] as num).toDouble());
    }).toList();

    final profits = _monthlyTrend.map((e) => (e['profit'] as num).toDouble()).toList();
    final minProfit = profits.reduce((a, b) => a < b ? a : b);
    final maxProfit = profits.reduce((a, b) => a > b ? a : b);
    final double yMin = minProfit < 0 ? minProfit * 1.1 : 0.0;
    final double yMax = maxProfit > 0 ? maxProfit * 1.1 : 10.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Net Profit Trend (Last 12 Months)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _monthlyTrend.length) {
                            return Text(
                              _monthlyTrend[index]['month'].substring(0, 3),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'Ksh ${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 60,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: _monthlyTrend.length - 1.toDouble(),
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: primaryGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: primaryGreen.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: primaryGreen,
                ),
                const SizedBox(width: 4),
                const Text('Net Profit'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrend() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Add Expense',
                    Icons.money_off,
                    Colors.red,
                        () => _showAddExpenseDialog(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Add Income',
                    Icons.attach_money,
                    Colors.green,
                        () => _showAddIncomeDialog(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------- Dialogs ----------

  void _showAddExpenseDialog() {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      items: const [
                        DropdownMenuItem(value: 'Feed', child: Text('Feed')),
                        DropdownMenuItem(value: 'Veterinary', child: Text('Veterinary')),
                        DropdownMenuItem(value: 'Labor', child: Text('Labor')),
                        DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => categoryController.text = value ?? '',
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (Ksh)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          selectedDate = date;
                          setStateDialog(() {});
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
                  onPressed: isSaving ? null : () async {
                    if (isSaving) return;
                    setStateDialog(() => isSaving = true);

                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      setStateDialog(() => isSaving = false);
                      return;
                    }
                    await _firestore.addExpense({
                      'category': categoryController.text.isEmpty ? 'Other' : categoryController.text,
                      'amount': amount,
                      'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                      'date': selectedDate.toIso8601String().split('T')[0],
                    });
                    Navigator.pop(context);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense added successfully')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddIncomeDialog() {
    final sourceController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Other Income'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: sourceController,
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (Ksh)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          selectedDate = date;
                          setStateDialog(() {});
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
                  onPressed: isSaving ? null : () async {
                    if (isSaving) return;
                    setStateDialog(() => isSaving = true);

                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      setStateDialog(() => isSaving = false);
                      return;
                    }
                    await _firestore.addOtherIncome({
                      'source': sourceController.text.isEmpty ? 'Other' : sourceController.text,
                      'amount': amount,
                      'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                      'date': selectedDate.toIso8601String().split('T')[0],
                    });
                    Navigator.pop(context);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Income added successfully')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money_off, color: Colors.red),
              title: const Text('Add Expense'),
              onTap: () {
                Navigator.pop(context);
                _showAddExpenseDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('Add Other Income'),
              onTap: () {
                Navigator.pop(context);
                _showAddIncomeDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}