// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';
import 'add_animal_screen.dart';
import 'sales_screen.dart';
import 'animal_management_screen.dart';
import 'milk_production_screen.dart';
import 'reports_screen.dart';
import 'more_screen.dart';
import 'package:intl/intl.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';
import 'finance_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestore = FirestoreService();

  int _selectedIndex = 0;
  String _farmerName = 'Farmer';
  String _farmerEmail = '';
  String _farmerPhone = '';
  String _currentTime = '';

  // Dashboard stats (cached + live)
  int _totalAnimals = 0;
  double _todayMilk = 0;
  int _pregnantCows = 0;
  double _monthlyRevenue = 0;
  int _alertCount = 0;
  double _yesterdayMilk = 0;

  bool _isLoading = true;
  bool _isFirstLoad = true;  // track first load
  int _unreadCount = 0;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCachedStats();         // show cached data immediately
    _loadFarmData(showLoading: true); // then fetch fresh data (shows spinner only first time)
    _loadActivities();
    _updateTime();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    setState(() {
      _currentTime = greeting;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _farmerName = prefs.getString('userName') ?? 'Farmer';
          _farmerEmail = prefs.getString('userEmail') ?? '';
          _farmerPhone = prefs.getString('userPhone') ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  /// Load cached stats from SharedPreferences (instant display)
  Future<void> _loadCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _totalAnimals = prefs.getInt('cached_animals') ?? 0;
          _todayMilk = prefs.getDouble('cached_today_milk') ?? 0.0;
          _pregnantCows = prefs.getInt('cached_pregnant_cows') ?? 0;
          _monthlyRevenue = prefs.getDouble('cached_monthly_revenue') ?? 0.0;
          _alertCount = prefs.getInt('cached_alert_count') ?? 0;
          _yesterdayMilk = prefs.getDouble('cached_yesterday_milk') ?? 0.0;
        });
      }
    } catch (e) {
      print('Error loading cached stats: $e');
    }
  }

  /// Save fresh stats to SharedPreferences
  Future<void> _cacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_animals', _totalAnimals);
      await prefs.setDouble('cached_today_milk', _todayMilk);
      await prefs.setInt('cached_pregnant_cows', _pregnantCows);
      await prefs.setDouble('cached_monthly_revenue', _monthlyRevenue);
      await prefs.setInt('cached_alert_count', _alertCount);
      await prefs.setDouble('cached_yesterday_milk', _yesterdayMilk);
    } catch (e) {
      print('Error caching stats: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _firestore.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (e) {
      print('Error loading unread count: $e');
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  /// Fetch fresh data from Firestore; optionally show a loading spinner
  Future<void> _loadFarmData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoading = true);

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

      final totalAnimals = await _firestore.getAnimalCount();
      final todayMilk = await _firestore.getTodayMilkTotal(today);
      final yesterdayMilk = await _firestore.getTodayMilkTotal(yesterday);
      final pregnantCows = await _firestore.getPregnantCount();
      final monthlySales = await _firestore.getMonthlySales();
      final lowStock = await _firestore.getLowStockItems();

      int alertCount = lowStock.length;

      if (mounted) {
        setState(() {
          _totalAnimals = totalAnimals;
          _todayMilk = todayMilk;
          _yesterdayMilk = yesterdayMilk;
          _pregnantCows = pregnantCows;
          _monthlyRevenue = monthlySales;
          _alertCount = alertCount;
          _isLoading = false;
          _isFirstLoad = false;
        });
        // Cache the updated stats
        await _cacheStats();
      }
    } catch (e) {
      print('❌ Critical error in _loadFarmData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _loadActivities() async {
    try {
      final activities = await _firestore.getTodayActivities();
      if (mounted) setState(() => _activities = activities);
    } catch (e) {
      print('Error loading activities: $e');
      if (mounted) setState(() => _activities = []);
    }
  }

  Future<void> _clearActivities() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Activities'),
        content: const Text('Are you sure you want to clear all today\'s activities?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _firestore.deleteTodayActivities();
      setState(() => _activities.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activities cleared successfully')),
      );
    } catch (e) {
      setState(() => _activities.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activities cleared locally (Firestore sync skipped)')),
      );
    }
  }

  double _getMilkTrend() {
    if (_yesterdayMilk == 0) return 0;
    return ((_todayMilk - _yesterdayMilk) / _yesterdayMilk) * 100;
  }

  Future<void> _refreshData() async {
    // Silent refresh – no loading spinner, only background update
    await _loadFarmData(showLoading: false);
    await _loadActivities();
    await _loadUnreadCount();
  }

  void _onNavTap(int index) {
    if (index == 3 && RoleService.isWorker()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reports are not available for your role'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _navigateTo(String target) {
    switch (target) {
      case 'animals':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AnimalManagementScreen()),
        ).then((_) => _refreshData());
        break;
      case 'milk':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MilkProductionScreen()),
        ).then((_) => _refreshData());
        break;
      case 'revenue':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FinanceScreen()),
        ).then((_) => _refreshData());
        break;
      case 'alerts':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NotificationsScreen()),
        ).then((_) => _loadUnreadCount());
        break;
    }
  }

  bool get _isSmallScreen => MediaQuery.of(context).size.height < 700;
  double get _heroHeight => _isSmallScreen ? 140 : 170;
  double get _quickActionHeight => _isSmallScreen ? 76 : 92;
  double get _metricHeight => _isSmallScreen ? 110 : 130;
  EdgeInsets get _defaultPadding => EdgeInsets.all(_isSmallScreen ? 12 : 16);
  double get _defaultSpacing => _isSmallScreen ? 12 : 16;
  double get _largeSpacing => _isSmallScreen ? 16 : 24;
  double get _extraSpacing => _isSmallScreen ? 20 : 32;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          sizing: StackFit.expand,
          children: [
            _buildHomeContent(),
            const AnimalManagementScreen(),
            const MilkProductionScreen(),
            ReportsScreen(),
            const MoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildHomeContent() {
    // Show spinner only on first load; after that, cached data appears instantly
    return _isLoading && _isFirstLoad
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: _defaultSpacing),
              children: [
                SizedBox(height: _defaultSpacing),
                _buildHeader(),
                SizedBox(height: _defaultSpacing),
                _buildHeroCard(),
                SizedBox(height: _largeSpacing),
                _buildQuickActions(),
                SizedBox(height: _largeSpacing),
                _buildStatsStrip(),
                SizedBox(height: _largeSpacing),
                _buildKeyMetrics(),
                SizedBox(height: _largeSpacing),
                _buildActivitiesSection(),
                SizedBox(height: _extraSpacing),
              ],
            ),
          );
  }

  // ========== HEADER ==========
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_currentTime 👋, $_farmerName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _farmerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          'Ithare Farm',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, size: 24),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const NotificationsScreen()),
                          ).then((_) => _loadUnreadCount());
                        },
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileEditScreen(
                            currentName: _farmerName,
                            currentEmail: _farmerEmail,
                            currentPhone: _farmerPhone,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadUserData();
                        _updateTime();
                        _refreshData(); // silent refresh after profile edit
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF15803D), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE8F5E9),
                        child: const Icon(
                          Icons.person,
                          size: 26,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== COW IMAGE ==========
  Widget _buildCowImage() {
    return Image.asset(
      'assets/images/40b1c96e-04b8-48d3-9fa2-e89efea647ee.png',
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('🐄 Cow image error: $error');
        return const Text(
          '🐮',
          style: TextStyle(fontSize: 35),
        );
      },
    );
  }

  // ========== HERO CARD ==========
  Widget _buildHeroCard() {
    final milkTrend = _getMilkTrend();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      height: _heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/farm_bg.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F6B28), Color(0xFF22C55E)],
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F6B28).withOpacity(0.15),
                  const Color(0xFF22C55E).withOpacity(0.1),
                ],
              ),
            ),
          ),
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Opacity(
              opacity: 0.15,
              child: Row(
                children: List.generate(
                  3,
                  (index) => const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.pets, size: 24, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF2E7D32),
                    child: ClipOval(
                      child: _buildCowImage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Farm Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Healthy Herd',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'All animals healthy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          if (milkTrend != 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: milkTrend > 0
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    milkTrend > 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10,
                                    color: milkTrend > 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${milkTrend.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: milkTrend > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHeroStat(Icons.pets, '$_totalAnimals', 'Animals'),
                  _buildHeroStat(Icons.pregnant_woman, '$_pregnantCows', 'Pregnant'),
                  _buildHeroStat(Icons.warning_amber, '$_alertCount', 'Alerts'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ========== QUICK ACTIONS ==========
  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: _defaultSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickActionCard(
                icon: Icons.qr_code_scanner,
                label: 'Add Animal',
                subtitle: 'Register new cow',
                color: const Color(0xFF15803D),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddAnimalScreen()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildQuickActionCard(
                icon: Icons.water_drop,
                label: 'Record Milk',
                subtitle: "Today's production",
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MilkProductionScreen()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildQuickActionCard(
                icon: Icons.receipt_long,
                label: 'Record Sale',
                subtitle: 'Milk or animal sale',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SalesScreen()),
                  ).then((_) => _refreshData());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: _quickActionHeight,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.6)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ========== STATS STRIP ==========
  Widget _buildStatsStrip() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatStripItem(
              '🥛', '${_todayMilk.toStringAsFixed(0)}L', 'Today', const Color(0xFFE0F2FE)),
          Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
          _buildStatStripItem(
              '💰', 'Ksh ${_monthlyRevenue.toStringAsFixed(0)}', 'Revenue', const Color(0xFFFEF3C7)),
          Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
          _buildStatStripItem(
              '🐄', '$_totalAnimals', 'Animals', const Color(0xFFDCFCE7)),
        ],
      ),
    );
  }

  Widget _buildStatStripItem(
      String icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(icon, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ========== KEY METRICS ==========
  Widget _buildKeyMetrics() {
    final milkTrend = _getMilkTrend();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: _defaultSpacing),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: 'assets/images/black-white-cow-grazing-meadow_190619-2738.jpg',
                      value: _totalAnimals.toString(),
                      title: 'Total Animals',
                      subtitle: 'All animals',
                      color: const Color(0xFF15803D),
                      iconColor: const Color(0xFF15803D),
                      trend: '+2 this month',
                      trendUp: true,
                      onTap: () => _navigateTo('animals'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.water_drop,
                      value: '${_todayMilk.toStringAsFixed(0)}L',
                      title: 'Milk Today',
                      subtitle: 'Total produced',
                      color: const Color(0xFF3B82F6),
                      iconColor: const Color(0xFF3B82F6),
                      trend: milkTrend != 0
                          ? '${milkTrend.abs().toStringAsFixed(0)}% from yesterday'
                          : null,
                      trendUp: milkTrend > 0,
                      onTap: () => _navigateTo('milk'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _defaultSpacing),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.attach_money,
                      value: 'Ksh ${_monthlyRevenue.toStringAsFixed(0)}',
                      title: 'Revenue',
                      subtitle: "This month",
                      color: const Color(0xFFF59E0B),
                      iconColor: const Color(0xFFF59E0B),
                      trend: '+12% this month',
                      trendUp: true,
                      onTap: () => _navigateTo('revenue'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.warning_amber,
                      value: _alertCount.toString(),
                      title: 'Alerts',
                      subtitle: 'Active',
                      color: const Color(0xFFEF4444),
                      iconColor: const Color(0xFFEF4444),
                      trend: _alertCount > 0 ? 'Requires attention' : null,
                      trendUp: false,
                      onTap: () => _navigateTo('alerts'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required dynamic icon,
    required String value,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    String? trend,
    bool? trendUp,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _metricHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: icon is String
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        icon,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.pets, size: 24, color: Colors.white);
                        },
                      ),
                    )
                  : Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (trendUp == true ? Colors.green : Colors.red)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendUp == true
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 10,
                            color: trendUp == true ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              trend,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: trendUp == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== DYNAMIC ACTIVITIES SECTION ==========
  Widget _buildActivitiesSection() {
    if (_activities.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: _defaultSpacing),
        child: const Text(
          'No activities today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Activities",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _clearActivities,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      'View All →',
                      style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: _defaultSpacing),
          ..._activities.map(
            (activity) => _buildActivityCard(
              title: activity['title'],
              subtitle: activity['subtitle'],
              status: activity['status'],
              statusColor: Color(
                  int.parse(activity['statusColor'].substring(1), radix: 16) +
                      0xFF000000),
              statusBg: Color(
                  int.parse(activity['statusBg'].substring(1), radix: 16) +
                      0xFF000000),
              icon: _getIconData(activity['icon']),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tapped: ${activity['title']}')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'pregnant_woman':
        return Icons.pregnant_woman;
      case 'warning_amber':
        return Icons.warning_amber;
      case 'water_drop':
        return Icons.water_drop;
      case 'vaccines':
        return Icons.vaccines;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildActivityCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 65,
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF15803D)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  // ========== PROFESSIONAL BOTTOM NAVIGATION ==========
  Widget _buildBottomNavBar() {
    final iconSize = _isSmallScreen ? 22.0 : 26.0;
    final fontSize = _isSmallScreen ? 10.0 : 12.0;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
      selectedItemColor: const Color(0xFF00C853),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF00C853),
      ),
      unselectedLabelStyle: TextStyle(fontSize: fontSize, color: const Color(0xFF9CA3AF)),
      currentIndex: _selectedIndex,
      onTap: _onNavTap,
      items: [
        _buildNavItem(Icons.home, 'Home', 0, iconSize: iconSize),
        _buildNavItem(
          'assets/images/black-white-cow-grazing-meadow_190619-2738.jpg',
          'Animals',
          1,
          isImage: true,
          iconSize: iconSize,
        ),
        _buildNavItem(Icons.local_drink, 'Milk', 2, iconSize: iconSize),
        _buildNavItem(Icons.pie_chart, 'Reports', 3, iconSize: iconSize),
        _buildNavItem(Icons.menu, 'More', 4, iconSize: iconSize),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(
      dynamic icon, String label, int index,
      {bool isImage = false, double iconSize = 26.0}) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: isImage
            ? Container(
                width: iconSize,
                height: iconSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    icon,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets, size: 26, color: Color(0xFF9CA3AF));
                    },
                  ),
                ),
              )
            : Icon(
                icon,
                size: iconSize,
                color: isSelected ? const Color(0xFF00C853) : const Color(0xFF9CA3AF),
              ),
      ),
      label: label,
    );
  }
}