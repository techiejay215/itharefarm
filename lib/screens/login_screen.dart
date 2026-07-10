import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/colors.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'Farm Owner';

  final List<String> _roles = [
    'Farm Owner',
    'Farm Manager',
    'Farm Worker',
    'Veterinarian',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (user != null) {
        // Login successful – navigation handled by AuthWrapper
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      _showError(message);
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔐 NEW: Send a password reset email
  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email first');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error sending reset email';
      if (e.code == 'user-not-found') msg = 'No user with that email.';
      _showError(msg);
    } catch (e) {
      _showError('Could not send reset email. Try again later.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_emotions_outlined,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Ithare Farm',
                style: TextStyle(
                  fontSize: AppFontSizes.xlarge,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Dairy Manager',
                style: TextStyle(
                  fontSize: AppFontSizes.medium,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Email
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'farmer@itharefarm.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Password
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textLight,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Role dropdown (UI only)
              const Text('Login as', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                    onChanged: (value) => setState(() => _selectedRole = value!),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Sign In button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg)),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                      )
                    : const Text('Sign In'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Forgot Password (now works!)
              TextButton(
                onPressed: _sendPasswordReset,
                child: const Text('Forgot Password?', style: TextStyle(color: AppColors.textLight)),
              ),

              // Sign Up link
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Decorative icon
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                ),
                child: const Center(
                  child: Icon(Icons.agriculture, size: 40, color: AppColors.primaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}