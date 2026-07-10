// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    // Wait 2 seconds on splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cow icon in circular background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_emotions_outlined,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Farm name
            const Text(
              'Ithare Farm',
              style: TextStyle(
                fontSize: AppFontSizes.xlarge,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1,
              ),
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Subtitle
            const Text(
              'Dairy Manager',
              style: TextStyle(
                fontSize: AppFontSizes.medium,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl * 2),
            
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}