// lib/screens/milk_production_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../widgets/milk_entry_dialog.dart';
import '../widgets/top_performer_card.dart';

class MilkProductionScreen extends StatefulWidget {
  const MilkProductionScreen({super.key});

  @override
  State<MilkProductionScreen> createState() => _MilkProductionScreenState();
}

class _MilkProductionScreenState extends State<MilkProductionScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _todayRecords = [];
  Map<String, double> _sessionBreakdown = {};
  double _totalMilk = 0;
  List<Map<String, dynamic>> _topProducers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSavingMilk = false; // ← NEW guard flag

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🔍 Updated search to include animal name
  List<Map<String, dynamic>> get _filteredRecords {
    if (_searchQuery.isEmpty) return _todayRecords;
    final query = _searchQuery.toLowerCase();
    return _todayRecords.where((record) {
      final name = (record['name'] ?? '').toString().toLowerCase();
      final earTag = (record['ear_tag'] ?? '').toString().toLowerCase();
      final breed = (record['breed'] ?? '').toString().toLowerCase();
      return name.contains(query) || earTag.contains(query) || breed.contains(query);
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final records = await _firestore.getTodayMilkRecordsWithAnimals();
    final breakdown = await _firestore.getTodaySessionBreakdown();
    final total = await _firestore.getTodayTotalMilk();
    final topProducers = await _firestore.getTopProducers();

    setState(() {
      _todayRecords = records;
      _sessionBreakdown = breakdown;
      _totalMilk = total;
      _topProducers = topProducers;
      _isLoading = false;
      // Clear search when data refreshes
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _saveMilkRecord(
    String animalId,
    String earTag,
    double morning,
    double midday,
    double evening, {
    String? animalName,
  }) async {
    // 🔒 Prevent double submission
    if (_isSavingMilk) return;
    _isSavingMilk = true;

    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      final snapshot = await _firestore
          .getMilkRecordsForAnimal(animalId)
          .first;
      final existing = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['date'] == today;
      }).toList();

      if (existing.isNotEmpty) {
        await _firestore.updateMilkRecord(existing.first.id, {
          'morning': morning,
          'midday': midday,
          'evening': evening,
        });
      } else {
        await _firestore.addMilkRecord({
          'animalId': animalId,
          'date': today,
          'morning': morning,
          'midday': midday,
          'evening': evening,
        });
      }

      // ✅ Add notification
      await _firestore.addNotification({
        'title': 'Milk Recorded',
        'message': 'Milk for ${animalName ?? 'Cow #$earTag'} recorded: ${(morning + midday + evening).toStringAsFixed(0)}L',
        'type': 'milk',
        'is_read': false,
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Milk record saved for ${animalName ?? 'Cow #$earTag'}'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      _isSavingMilk = false;
    }
  }

  Future<void> _deleteMilkRecord(String animalId, String earTag, {String? animalName}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final snapshot = await _firestore
        .getMilkRecordsForAnimal(animalId)
        .first;
    final existing = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['date'] == today;
    }).toList();

    if (existing.isNotEmpty) {
      await _firestore.deleteMilkRecord(existing.first.id);
      // ✅ Add notification
      await _firestore.addNotification({
        'title': 'Milk Record Deleted',
        'message': 'Milk record for ${animalName ?? 'Cow #$earTag'} was deleted',
        'type': 'milk_deleted',
        'is_read': false,
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Milk record deleted for ${animalName ?? 'Cow #$earTag'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showMilkDialog(Map<String, dynamic> record) {
    final animalId = record['animalId'];
    final earTag = record['ear_tag'];
    final breed = record['breed'];
    final name = record['name'] ?? 'Cow #$earTag';
    final morning = (record['morning'] as num?)?.toDouble() ?? 0.0;
    final midday = (record['midday'] as num?)?.toDouble() ?? 0.0;
    final evening = (record['evening'] as num?)?.toDouble() ?? 0.0;

    final hasRecord = (morning + midday + evening) > 0;

    showDialog(
      context: context,
      builder: (context) => MilkEntryDialog(
        animalId: animalId,
        earTag: earTag,
        breed: breed,
        name: name,
        currentMorning: morning,
        currentMidday: midday,
        currentEvening: evening,
        onSave: (morning, midday, evening) async {
          await _saveMilkRecord(animalId, earTag, morning, midday, evening, animalName: name);
        },
        onDelete: hasRecord
            ? () async {
                await _deleteMilkRecord(animalId, earTag, animalName: name);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Milk Production - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Today's Total Card ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        const Text(
                          "Today's Total Milk",
                          style: TextStyle(
                            fontSize: AppFontSizes.small,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _isLoading ? '---' : '${_totalMilk.toStringAsFixed(0)} L',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSessionCard('🌅 Morning', _sessionBreakdown['morning'] ?? 0),
                              const SizedBox(width: AppSpacing.md),
                              _buildSessionCard('☀️ Midday', _sessionBreakdown['midday'] ?? 0),
                              const SizedBox(width: AppSpacing.md),
                              _buildSessionCard('🌙 Evening', _sessionBreakdown['evening'] ?? 0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Search Bar ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, ear tag, or breed...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
            ),

            // ─── Today's Milking List Header ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      "Today's Milking List",
                      style: TextStyle(
                        fontSize: AppFontSizes.medium,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            // ─── Milk Records List ───
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredRecords.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No animals found'
                        : 'No matching animals found',
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = _filteredRecords[index];
                    final morning = (record['morning'] as num?)?.toDouble() ?? 0;
                    final midday = (record['midday'] as num?)?.toDouble() ?? 0;
                    final evening = (record['evening'] as num?)?.toDouble() ?? 0;
                    final total = (record['total'] as num?)?.toDouble() ?? 0;
                    final isComplete = morning > 0 && midday > 0 && evening > 0;

                    final animalName = record['name'] ?? 'Cow #${record['ear_tag']}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          onTap: () => _showMilkDialog(record),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.amber.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isComplete ? Icons.check : Icons.water_drop,
                              color: isComplete ? AppColors.primary : AppColors.amber,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            animalName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Ear Tag: #${record['ear_tag']} · ${record['breed']}',
                            style: const TextStyle(fontSize: AppFontSizes.small),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${total.toStringAsFixed(0)}L',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '🌅$morning ☀️$midday 🌙$evening',
                                    style: const TextStyle(
                                      fontSize: AppFontSizes.small,
                                      color: AppColors.textLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppColors.primary),
                                onPressed: () => _showMilkDialog(record),
                                tooltip: 'Edit milk record',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filteredRecords.length,
                ),
              ),

            // ─── Top Performers ───
            if (_topProducers.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'Top Performers (Last 7 Days)',
                        style: TextStyle(
                          fontSize: AppFontSizes.medium,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final performer = _topProducers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TopPerformerCard(
                          rank: index + 1,
                          earTag: performer['ear_tag'],
                          breed: performer['breed'],
                          totalMilk: (performer['total_milk'] as num?)?.toDouble() ?? 0,
                          avgDaily: (performer['avg_daily'] as num?)?.toDouble() ?? 0,
                        ),
                      ),
                    );
                  },
                  childCount: _topProducers.length,
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'milk_fab',
        onPressed: () {
          if (_todayRecords.isNotEmpty) {
            _showMilkDialog(_todayRecords.first);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildSessionCard(String session, double amount) {
    return Column(
      children: [
        Text(
          session,
          style: const TextStyle(
            fontSize: AppFontSizes.small,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _isLoading ? '---' : '${amount.toStringAsFixed(0)} L',
          style: const TextStyle(
            fontSize: AppFontSizes.large,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}