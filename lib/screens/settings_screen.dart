// lib/screens/settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';  // ✅ Added
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestore = FirestoreService();

  String _farmerName = 'John Mwangi';
  String _farmerEmail = 'john@itharefarm.com';
  String _farmerPhone = '0712 345 678';
  String _farmName = 'Ithare Farm';
  String _farmLocation = 'Kisii, Kenya';
  String _farmSize = '15 acres';
  String _licenseNumber = 'ITH-2026-001';

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _biometricLogin = false;

  List<Map<String, dynamic>> _users = [];
  String _userRole = 'Farm Owner';
  bool _isLoading = true;

  bool _isEditingProfile = false;
  bool _isEditingFarm = false;
  bool _isAddingUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUsers();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _farmerName = prefs.getString('userName') ?? 'John Mwangi';
      _farmerEmail = prefs.getString('userEmail') ?? 'john@itharefarm.com';
      _userRole = prefs.getString('userRole') ?? 'Farm Owner';
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _darkMode = prefs.getBool('darkMode') ?? false;
      _biometricLogin = prefs.getBool('biometricLogin') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _loadUsers() async {
    final users = await _firestore.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('biometricLogin', _biometricLogin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  // ============ EDIT SHEETS (with guards) ============

  void _editProfile() {
    if (_isEditingProfile) return;
    _isEditingProfile = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditProfileSheet(
        name: _farmerName,
        email: _farmerEmail,
        phone: _farmerPhone,
        onSave: (name, email, phone) {
          setState(() {
            _farmerName = name;
            _farmerEmail = email;
            _farmerPhone = phone;
          });
        },
      ),
    ).then((_) => _isEditingProfile = false);
  }

  void _editFarmDetails() {
    if (_isEditingFarm) return;
    _isEditingFarm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditFarmSheet(
        farmName: _farmName,
        farmLocation: _farmLocation,
        farmSize: _farmSize,
        onSave: (name, location, size) {
          setState(() {
            _farmName = name;
            _farmLocation = location;
            _farmSize = size;
          });
        },
      ),
    ).then((_) => _isEditingFarm = false);
  }

  void _addUser() {
    if (_isAddingUser) return;
    _isAddingUser = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddUserSheet(
        onUserAdded: _loadUsers,
      ),
    ).then((_) => _isAddingUser = false);
  }

  // ============ MANUAL BACKUP ============

  Future<void> _manualBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final path = await _firestore.exportAllDataAsCsv();
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Ithare Farm Data Backup',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created and shared'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============ CLEAR ALL DATA ============

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear All Data'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action will permanently delete ALL data associated with your account, including:',
              ),
              SizedBox(height: 12),
              Text('• Animals & milk records'),
              Text('• Health & breeding records'),
              Text('• Customers & sales'),
              Text('• Feed inventory & purchases'),
              Text('• Expenses & income'),
              Text('• Notifications'),
              SizedBox(height: 12),
              Text(
                'This cannot be undone. Your user profile will remain intact.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestore.clearAllData();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ BUILD ============

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
        title: const Text('Settings - Ithare Farm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Farm Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
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
                                child: const Icon(Icons.agriculture, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Farm',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    Text(
                                      _farmName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _editFarmDetails,
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildInfoRow('Location', _farmLocation),
                          _buildInfoRow('Size', _farmSize),
                          _buildInfoRow('License', _licenseNumber),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Profile Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
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
                                child: const Icon(Icons.person, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Profile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    Text(
                                      _farmerName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _editProfile,
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildInfoRow('Email', _farmerEmail),
                          _buildInfoRow('Phone', _farmerPhone),
                          _buildInfoRow('Role', _userRole),
                        ],
                      ),
                    ),
                  ),

                  // User Management (Farm Owner only)
                  if (_userRole == 'Farm Owner') ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.people, color: Colors.blue),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'User Management',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: AppColors.primary),
                                  onPressed: _addUser,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_users.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text('No additional users'),
                                ),
                              )
                            else
                              ..._users.map((user) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    user['name'][0].toUpperCase(),
                                    style: const TextStyle(color: AppColors.primary),
                                  ),
                                ),
                                title: Text(user['name']),
                                subtitle: Text(user['role']),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _firestore.deleteUser(user['id']).then((_) => _loadUsers()),
                                ),
                              )),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Data Management Section
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storage, color: Colors.teal),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Data Management',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.backup, color: AppColors.primary),
                            title: const Text('Backup Data'),
                            subtitle: const Text('Export all data as CSV and share'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _manualBackup,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Danger Zone
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning, color: Colors.red),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.delete_forever, color: Colors.red),
                            title: const Text(
                              'Clear All Data',
                              style: TextStyle(color: Colors.red),
                            ),
                            subtitle: const Text(
                              'Permanently delete all farm records and start fresh',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.red),
                            onTap: _clearAllData,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Preferences Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.settings, color: Colors.orange),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Preferences',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                              _savePreferences();
                            },
                            title: const Text('Push Notifications'),
                            secondary: const Icon(Icons.notifications),
                            activeColor: AppColors.primary,
                          ),
                          SwitchListTile(
                            value: _darkMode,
                            onChanged: (value) {
                              setState(() => _darkMode = value);
                              _savePreferences();
                            },
                            title: const Text('Dark Mode'),
                            secondary: const Icon(Icons.dark_mode),
                            activeColor: AppColors.primary,
                          ),
                          SwitchListTile(
                            value: _biometricLogin,
                            onChanged: (value) {
                              setState(() => _biometricLogin = value);
                              _savePreferences();
                            },
                            title: const Text('Biometric Login'),
                            secondary: const Icon(Icons.fingerprint),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // About Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.info, color: Colors.purple),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'About',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.emoji_emotions_outlined),
                            title: const Text('Ithare Farm Dairy Manager'),
                            subtitle: const Text('Version 1.0.0'),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.verified),
                            title: const Text('License'),
                            subtitle: Text('Licensed to Ithare Farm\nLicense #: $_licenseNumber'),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.support_agent),
                            title: const Text('Support'),
                            subtitle: const Text('support@itharefarm.com\n+254 700 000 000'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLight)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// -------------------- Edit Sheets --------------------

// Edit Profile Sheet (unchanged except guard boolean not needed)
class EditProfileSheet extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final Function(String, String, String) onSave;

  const EditProfileSheet({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _save() {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    widget.onSave(
      _nameController.text,
      _emailController.text,
      _phoneController.text,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.primary),
    );
  }
}

// Edit Farm Sheet (unchanged)
class EditFarmSheet extends StatefulWidget {
  final String farmName;
  final String farmLocation;
  final String farmSize;
  final Function(String, String, String) onSave;

  const EditFarmSheet({
    super.key,
    required this.farmName,
    required this.farmLocation,
    required this.farmSize,
    required this.onSave,
  });

  @override
  State<EditFarmSheet> createState() => _EditFarmSheetState();
}

class _EditFarmSheetState extends State<EditFarmSheet> {
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _sizeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.farmName);
    _locationController = TextEditingController(text: widget.farmLocation);
    _sizeController = TextEditingController(text: widget.farmSize);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Edit Farm Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Farm Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sizeController,
            decoration: const InputDecoration(labelText: 'Farm Size (acres)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _save() {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    widget.onSave(
      _nameController.text,
      _locationController.text,
      _sizeController.text,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Farm details updated'), backgroundColor: AppColors.primary),
    );
  }
}

// Add User Sheet (unchanged)
class AddUserSheet extends StatefulWidget {
  final VoidCallback onUserAdded;

  const AddUserSheet({super.key, required this.onUserAdded});

  @override
  State<AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<AddUserSheet> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'Farm Worker';
  bool _isSaving = false;

  final List<String> _roles = ['Farm Owner', 'Farm Manager', 'Farm Worker', 'Veterinarian'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Add User',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add User'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    _firestore.addUser({
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'role': _selectedRole,
    });
    widget.onUserAdded();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User added'), backgroundColor: AppColors.primary),
    );
  }
}