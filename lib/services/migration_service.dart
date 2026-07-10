import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';

class MigrationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> migrateAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in to migrate');

    print('🚀 Starting migration for user: ${user.uid}');

    // List of all SQLite tables to migrate
    final tables = [
      'animals', 'milk_records', 'health_records', 'breeding_records',
      'customers', 'sales', 'feed_inventory', 'feed_usage', 'feed_purchases',
      'expenses', 'other_income', 'vet_records', 'inventory',
      'inventory_purchases', 'notifications', 'users'
    ];

    for (final table in tables) {
      print('📦 Migrating table: $table');
      final records = await _dbHelper.database.then((db) => db.query(table));
      if (records.isEmpty) {
        print('⏭️  Table $table is empty, skipping.');
        continue;
      }

      for (final record in records) {
        // 🔥 Remove SQLite-specific fields that Firestore doesn't need
        record.remove('id');
        record.remove('sync_status');
        record.remove('remote_id');
        record.remove('deleted');
        // Keep 'created_at' and 'updated_at' (they will be overwritten by Firestore timestamps)

        // Add the userId
        record['userId'] = user.uid;

        // Firestore will set its own timestamps
        record['created_at'] = FieldValue.serverTimestamp();
        record['updated_at'] = FieldValue.serverTimestamp();

        // For Firestore, we use soft delete with a boolean flag
        record['deleted'] = false;

        // Insert into Firestore
        await _firestore.collection(table).add(record);
      }
      print('✅ Migrated ${records.length} records for table $table');
    }

    print('🎉 Migration complete!');
  }
}