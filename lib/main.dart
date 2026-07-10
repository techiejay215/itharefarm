// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/animal_management_screen.dart';
import 'screens/animal_profile_screen.dart';
import 'screens/add_animal_screen.dart';
import 'screens/milk_production_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/milk_report_screen.dart';
import 'screens/animal_report_screen.dart';
import 'screens/health_report_screen.dart';
import 'screens/breeding_report_screen.dart';
import 'screens/sales_report_screen.dart' as sales;
import 'screens/financial_report_screen.dart';
import 'screens/more_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/health_screen.dart';
import 'screens/breeding_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_edit_screen.dart';

// Services
import 'services/notification_service.dart';
import 'services/role_service.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================================
// 1. BACKGROUND MESSAGE HANDLER (top‑level)
// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.handleBackgroundMessage(message);
}
// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const IthareFarmApp());
}

class IthareFarmApp extends StatelessWidget {
  const IthareFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ithare Farm Dairy Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const HomeScreen(),
        '/animals': (context) => const AnimalManagementScreen(),
        '/animal_profile': (context) => const AnimalProfileScreen(animalId: ''),
        '/add_animal': (context) => const AddAnimalScreen(),
        '/milk': (context) => const MilkProductionScreen(),
        '/reports': (context) => ReportsScreen(),
        '/milk_report': (context) => const MilkReportScreen(),
        '/animal_report': (context) => const AnimalReportScreen(),
        '/health_report': (context) => const HealthReportScreen(),
        '/breeding_report': (context) => const BreedingReportScreen(),
        '/sales_report': (context) => sales.SalesReportScreen(),
        '/financial_report': (context) => const FinancialReportScreen(),
        '/more': (context) => const MoreScreen(),
        '/finance': (context) => const FinanceScreen(),
        '/health': (context) => const HealthScreen(),
        '/breeding': (context) => const BreedingScreen(),
        '/feed': (context) => FeedScreen(),
        '/sales': (context) => const SalesScreen(),
        '/inventory': (context) => InventoryScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingProfile = false;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Only initialize once
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isCheckingProfile) {
              _isCheckingProfile = true;
              NotificationService.setNavigatorKey(navigatorKey);
              NotificationService.initialize().then((_) {
                NotificationService.saveTokenToServer();
              });
              
              // ✅ Check profile setup after role is loaded
              RoleService.getCurrentUserRole().then((_) {
                _checkProfileSetup(context);
              });
            }
          });
          
          // Show loading while checking profile
          return const Scaffold(
            backgroundColor: AppColors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
    );
  }

  Future<void> _checkProfileSetup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileSet = prefs.getBool('profile_set') ?? false;
      
      // Check if user has a name stored
      final userName = prefs.getString('userName') ?? '';
      
      // Also check if the user's profile is actually set in Firestore
      final user = FirebaseAuth.instance.currentUser;
      bool hasProfileData = false;
      
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data['name'] != null && data['name']!.isNotEmpty) {
              hasProfileData = true;
            }
          }
        } catch (e) {
          print('Error checking Firestore profile: $e');
        }
      }
      
      // If profile is not set OR Firestore doesn't have name data
      if (!profileSet || !hasProfileData || userName.isEmpty) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileEditScreen(
                currentName: userName.isNotEmpty ? userName : '',
                currentEmail: user?.email ?? '',
                currentPhone: prefs.getString('userPhone') ?? '',
              ),
            ),
          ).then((result) async {
            if (result == true) {
              await prefs.setBool('profile_set', true);
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            } else {
              // If profile editing was cancelled, still go to home
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            }
          });
        }
      } else {
        // Profile is set, go to home
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('Error in _checkProfileSetup: $e');
      // On error, try to go home anyway
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }
}