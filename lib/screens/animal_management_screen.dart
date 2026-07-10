// lib/screens/animal_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../models/animal_model.dart';
import 'add_animal_screen.dart';
import 'animal_profile_screen.dart';

class AnimalManagementScreen extends StatefulWidget {
  const AnimalManagementScreen({super.key});

  @override
  State<AnimalManagementScreen> createState() => _AnimalManagementScreenState();
}

class _AnimalManagementScreenState extends State<AnimalManagementScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  List<Animal> _allAnimals = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _selectedTypeFilter = 'All';
  bool _isDeleting = false;   // ← new flag

  final List<String> _statusFilters = [
    'All', 'Lactating', 'Pregnant', 'Dry', 'Calf', 'Sold',
  ];

  final List<String> _typeFilters = [
    'All', 'Cow', 'Bull', 'Heifer',
  ];

  List<Animal> _applyFilters(List<Animal> animals) {
    List<Animal> filtered = animals;
    
    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((a) => a.status == _selectedStatusFilter).toList();
    }
    if (_selectedTypeFilter != 'All') {
      filtered = filtered.where((a) => a.animalType == _selectedTypeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        return a.earTag.contains(_searchQuery) ||
               a.breed.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (a.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }
    return filtered;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _onStatusFilterSelected(String filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });
  }

  void _onTypeFilterSelected(String filter) {
    setState(() {
      _selectedTypeFilter = filter;
    });
  }

  Future<void> _addAnimal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAnimalScreen()),
    );
    // Stream will auto-update
  }

  Future<void> _deleteAnimal(Animal animal) async {
    if (_isDeleting) return;   // 🔒 guard
    _isDeleting = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${animal.getDisplayName()}'),
        content: const Text('Are you sure you want to delete this animal? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.deleteAnimal(animal.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${animal.getDisplayName()} deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    _isDeleting = false;   // ← reset guard
  }

  Future<double> _getTodayMilkForAnimal(String animalId) async {
    return await _firestore.getTodayMilkForAnimal(animalId);
  }

  /// Returns a realistic animal emoji based on type
  String _getAnimalEmoji(String? type) {
    switch (type) {
      case 'Bull':
        return '🐂';
      case 'Cow':
      case 'Heifer':
      default:
        return '🐄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Animals - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addAnimal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name, ear tag or breed...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.filter_list),
              ),
            ),
          ),
          
          // Status filter chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatusFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onStatusFilterSelected(filter);
                      }
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected 
                          ? BorderSide.none
                          : const BorderSide(color: AppColors.border),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Animal type filter chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _typeFilters.length,
              itemBuilder: (context, index) {
                final filter = _typeFilters[index];
                final isSelected = _selectedTypeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onTypeFilterSelected(filter);
                      }
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected 
                          ? BorderSide.none
                          : const BorderSide(color: AppColors.border),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),

          // 🔥 StreamBuilder with emoji icons
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.getAnimals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                _allAnimals = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return Animal.fromMap(data);
                }).toList();

                final filteredAnimals = _applyFilters(_allAnimals);

                if (filteredAnimals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pets, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        const Text('No animals found', style: TextStyle(fontSize: 16, color: AppColors.textLight)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _addAnimal,
                          child: const Text('Add Your First Animal'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Animal count row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredAnimals.length} animals',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty || _selectedStatusFilter != 'All' || _selectedTypeFilter != 'All')
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _selectedStatusFilter = 'All';
                                  _selectedTypeFilter = 'All';
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 🔥 List of animals
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          setState(() {});
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredAnimals.length,
                          itemBuilder: (context, index) {
                            final animal = filteredAnimals[index];
                            return FutureBuilder<double>(
                              future: _getTodayMilkForAnimal(animal.id!),
                              builder: (context, snapshot) {
                                final milk = snapshot.data ?? 0;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AnimalProfileScreen(
                                            animalId: animal.id!,
                                            animal: animal,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // 🔹 Animal emoji with nice background
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _getAnimalEmoji(animal.animalType),
                                                style: const TextStyle(fontSize: 30),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      animal.getDisplayName(),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textDark,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(animal.status).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        animal.status,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: _getStatusColor(animal.status),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${animal.breed} | Tag: #${animal.earTag}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textLight,
                                                  ),
                                                ),
                                                if (animal.animalType != null)
                                                  Text(
                                                    'Type: ${animal.animalType}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textLight,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              if (animal.animalType == 'Cow')
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Today's Milk",
                                                      style: TextStyle(fontSize: 10, color: AppColors.textLight),
                                                    ),
                                                    Text(
                                                      '${milk.toStringAsFixed(0)}L',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                const Text(
                                                  'N/A',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textLight,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              const SizedBox(height: 8),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, size: 20),
                                                onSelected: (value) {
                                                  if (value == 'delete') {
                                                    _deleteAnimal(animal);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'animal_fab',
        onPressed: _addAnimal,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Lactating':
        return const Color(0xFF2E7D32);
      case 'Pregnant':
        return const Color(0xFFF9A825);
      case 'Dry':
        return const Color(0xFF757575);
      case 'Calf':
        return const Color(0xFF1976D2);
      case 'Sold':
        return const Color(0xFFD32F2F);
      default:
        return AppColors.primary;
    }
  }
}