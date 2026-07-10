// lib/screens/profile_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentPhone;

  const ProfileEditScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentPhone,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _phoneController = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String name = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();

      // 1. Save to SharedPreferences (local)
      await prefs.setString('userName', name);
      await prefs.setString('userEmail', email);
      await prefs.setString('userPhone', phone);

      // 2. Update Firestore user document (for server to read)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'last_active': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh HomeScreen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
              const Text(
                'Full Name',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Email',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Phone Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g. 0712 345 678',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}