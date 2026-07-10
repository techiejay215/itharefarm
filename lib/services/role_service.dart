import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  static const String roleOwner = 'Farm Owner';
  static const String roleManager = 'Farm Manager';
  static const String roleWorker = 'Farm Worker';
  static const String roleVet = 'Veterinarian';

  static String? _cachedRole;

  /// Fetches the current user's role from Firestore and caches it.
  static Future<String> getCurrentUserRole() async {
    if (_cachedRole != null) return _cachedRole!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return roleOwner;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final role = doc.data()?['role'] as String?;
      _cachedRole = role ?? roleOwner;
    } else {
      // Create a user document with default role (Farm Owner) if not exists.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': user.displayName ?? user.email ?? 'User',
        'email': user.email,
        'role': roleOwner,
        'created_at': FieldValue.serverTimestamp(),
      });
      _cachedRole = roleOwner;
    }
    return _cachedRole!;
  }

  static void clearCache() => _cachedRole = null;

  static bool isWorker() => _cachedRole == roleWorker;
  static bool isOwnerOrManager() =>
      _cachedRole == roleOwner || _cachedRole == roleManager;
}