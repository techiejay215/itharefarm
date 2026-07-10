import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // ========== Generic Helpers ==========

  Future<String> addDocument(String collection, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final newData = Map<String, dynamic>.from(data);
    newData['userId'] = user.uid;
    newData['created_at'] = FieldValue.serverTimestamp();
    newData['updated_at'] = FieldValue.serverTimestamp();
    newData['deleted'] = false;

    final docRef = await _firestore.collection(collection).add(newData);
    return docRef.id;
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    final newData = Map<String, dynamic>.from(data);
    newData['updated_at'] = FieldValue.serverTimestamp();
    await _firestore.collection(collection).doc(docId).update(newData);
  }

  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).update({
      'deleted': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getCollectionStream(String collection) {
    return _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .snapshots();
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await _firestore.collection(collection).doc(docId).get();
  }

  // ========== Animals ==========
  Future<String> addAnimal(Map<String, dynamic> animal) => addDocument('animals', animal);
  Future<void> updateAnimal(String docId, Map<String, dynamic> animal) => updateDocument('animals', docId, animal);
  Future<void> deleteAnimal(String docId) => deleteDocument('animals', docId);
  Stream<QuerySnapshot> getAnimals() => getCollectionStream('animals');

  Future<int> getAnimalCount() async {
    final snapshot = await _firestore
        .collection('animals')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  Future<int> getPregnantCount() async {
    final snapshot = await _firestore
        .collection('animals')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'Pregnant')
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  Future<Map<String, dynamic>> getAnimalReportData() async {
    final snapshot = await _firestore
        .collection('animals')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .get();
    final animals = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    int total = animals.length;
    int lactating = 0, pregnant = 0, dry = 0, calf = 0, sold = 0;
    for (var a in animals) {
      final status = a['status'] as String?;
      switch (status) {
        case 'Lactating': lactating++; break;
        case 'Pregnant': pregnant++; break;
        case 'Dry': dry++; break;
        case 'Calf': calf++; break;
        case 'Sold': sold++; break;
      }
    }
    return {
      'total': total,
      'lactating': lactating,
      'pregnant': pregnant,
      'dry': dry,
      'calf': calf,
      'sold': sold,
    };
  }

  // ========== NEW: Helper to get ear tags for multiple animals ==========
  Future<Map<String, String>> getAnimalEarTags(List<String> animalIds) async {
    if (animalIds.isEmpty) return {};
    final Map<String, String> tags = {};
    for (final id in animalIds) {
      final doc = await _firestore.collection('animals').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        tags[id] = data['ear_tag']?.toString() ?? 'Unknown';
      } else {
        tags[id] = 'Unknown';
      }
    }
    return tags;
  }

  // ========== Milk Records ==========
  Future<String> addMilkRecord(Map<String, dynamic> record) => addDocument('milk_records', record);
  Future<void> updateMilkRecord(String docId, Map<String, dynamic> record) => updateDocument('milk_records', docId, record);
  Future<void> deleteMilkRecord(String docId) => deleteDocument('milk_records', docId);
  Stream<QuerySnapshot> getMilkRecords() => getCollectionStream('milk_records');
  Stream<QuerySnapshot> getMilkRecordsForAnimal(String animalId) {
    return _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('animalId', isEqualTo: animalId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<double> getTodayMilkForAnimal(String animalId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('animalId', isEqualTo: animalId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return 0.0;
    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    final morning = (data['morning'] as num? ?? 0).toDouble();
    final midday = (data['midday'] as num? ?? 0).toDouble();
    final evening = (data['evening'] as num? ?? 0).toDouble();
    return morning + midday + evening;
  }

  Future<double> getTodayMilkTotal(String date) async {
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['morning'] as num? ?? 0) + (data['midday'] as num? ?? 0) + (data['evening'] as num? ?? 0);
    }
    return total;
  }

  Future<Map<String, double>> getTodaySessionBreakdown() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    double morning = 0, midday = 0, evening = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      morning += (data['morning'] as num? ?? 0).toDouble();
      midday += (data['midday'] as num? ?? 0).toDouble();
      evening += (data['evening'] as num? ?? 0).toDouble();
    }
    return {'morning': morning, 'midday': midday, 'evening': evening};
  }

  Future<double> getTodayTotalMilk() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['morning'] as num? ?? 0) + (data['midday'] as num? ?? 0) + (data['evening'] as num? ?? 0);
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getTodayMilkRecordsWithAnimals() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final animalsSnapshot = await _firestore
        .collection('animals')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .get();
    final animals = animalsSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    final milkSnapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    final milkRecords = milkSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    final result = <Map<String, dynamic>>[];
    for (var animal in animals) {
      final record = milkRecords.firstWhere(
        (r) => r['animalId'] == animal['id'],
        orElse: () => {'morning': 0, 'midday': 0, 'evening': 0},
      );
      result.add({
        'animalId': animal['id'],
        'ear_tag': animal['ear_tag'],
        'breed': animal['breed'],
        'name': animal['name'] ?? '',
        'morning': record['morning'] ?? 0,
        'midday': record['midday'] ?? 0,
        'evening': record['evening'] ?? 0,
        'total': (record['morning'] ?? 0) + (record['midday'] ?? 0) + (record['evening'] ?? 0),
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopProducers() async {
    final sevenDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7)));
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: sevenDaysAgo)
        .where('deleted', isEqualTo: false)
        .get();
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final animalId = data['animalId'] as String?;
      if (animalId == null) continue;
      final total = (data['morning'] as num? ?? 0) + (data['midday'] as num? ?? 0) + (data['evening'] as num? ?? 0);
      totals[animalId] = (totals[animalId] ?? 0) + total;
      counts[animalId] = (counts[animalId] ?? 0) + 1;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final result = <Map<String, dynamic>>[];
    for (var entry in sorted.take(5)) {
      final animalId = entry.key;
      final animalDoc = await _firestore.collection('animals').doc(animalId).get();
      if (animalDoc.exists) {
        final animalData = animalDoc.data() as Map<String, dynamic>;
        final count = counts[animalId] ?? 1;
        result.add({
          'ear_tag': animalData['ear_tag'] ?? 'Unknown',
          'breed': animalData['breed'] ?? '',
          'total_milk': entry.value,
          'avg_daily': entry.value / count,
        });
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getMilkReportData(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double totalMorning = 0, totalMidday = 0, totalEvening = 0;
    final distinctDates = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalMorning += (data['morning'] as num? ?? 0).toDouble();
      totalMidday += (data['midday'] as num? ?? 0).toDouble();
      totalEvening += (data['evening'] as num? ?? 0).toDouble();
      distinctDates.add(data['date'] as String);
    }
    final totalMilk = totalMorning + totalMidday + totalEvening;
    final distinctDays = distinctDates.length;
    final avgDaily = distinctDays > 0 ? totalMilk / distinctDays : 0;
    return {
      'total_milk': totalMilk,
      'avg_daily': avgDaily,
      'total_morning': totalMorning,
      'total_midday': totalMidday,
      'total_evening': totalEvening,
    };
  }

  // NEW: get list of milk records for a date range
  Future<List<Map<String, dynamic>>> getMilkRecordsForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Health Records ==========
  Future<String> addHealthRecord(Map<String, dynamic> record) => addDocument('health_records', record);
  Future<void> updateHealthRecord(String docId, Map<String, dynamic> record) => updateDocument('health_records', docId, record);
  Future<void> deleteHealthRecord(String docId) => deleteDocument('health_records', docId);
  Stream<QuerySnapshot> getHealthRecords() => getCollectionStream('health_records');

  Future<Map<String, dynamic>> getHealthReportData(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    final records = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    int total = records.length;
    int vaccinations = 0, deworming = 0, sickness = 0;
    for (var r in records) {
      final type = r['type'] as String?;
      switch (type) {
        case 'Vaccination': vaccinations++; break;
        case 'Deworming': deworming++; break;
        case 'Sickness': sickness++; break;
      }
    }
    return {
      'total': total,
      'vaccinations': vaccinations,
      'deworming': deworming,
      'sickness': sickness,
    };
  }

  // NEW: get list of health records for a date range
  Future<List<Map<String, dynamic>>> getHealthRecordsForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Breeding Records ==========
  Future<String> addBreedingRecord(Map<String, dynamic> record) => addDocument('breeding_records', record);
  Future<void> updateBreedingRecord(String docId, Map<String, dynamic> record) => updateDocument('breeding_records', docId, record);
  Future<void> deleteBreedingRecord(String docId) => deleteDocument('breeding_records', docId);
  Stream<QuerySnapshot> getBreedingRecords() => getCollectionStream('breeding_records');

  Future<List<Map<String, dynamic>>> getUpcomingCalvings() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final next30Days = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('event_type', isEqualTo: 'Expected Calving')
        .where('date', isGreaterThanOrEqualTo: today)
        .where('date', isLessThanOrEqualTo: next30Days)
        .where('deleted', isEqualTo: false)
        .orderBy('date')
        .get();
    final records = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    for (var record in records) {
      final animalId = record['animalId'] as String?;
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          record['ear_tag'] = animalData['ear_tag'] ?? 'Unknown';
          record['breed'] = animalData['breed'] ?? '';
        } else {
          record['ear_tag'] = 'Unknown';
          record['breed'] = '';
        }
      } else {
        record['ear_tag'] = 'Unknown';
        record['breed'] = '';
      }
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> getUpcomingHeats() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final next7Days = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7)));
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('event_type', isEqualTo: 'Heat Detected')
        .where('date', isGreaterThanOrEqualTo: today)
        .where('date', isLessThanOrEqualTo: next7Days)
        .where('deleted', isEqualTo: false)
        .orderBy('date')
        .get();
    final records = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    for (var record in records) {
      final animalId = record['animalId'] as String?;
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          record['ear_tag'] = animalData['ear_tag'] ?? 'Unknown';
          record['breed'] = animalData['breed'] ?? '';
        } else {
          record['ear_tag'] = 'Unknown';
          record['breed'] = '';
        }
      } else {
        record['ear_tag'] = 'Unknown';
        record['breed'] = '';
      }
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> getRecentlyBred() async {
    final thirtyDaysAgo = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30)));
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('event_type', isEqualTo: 'Inseminated')
        .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    final records = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    for (var record in records) {
      final animalId = record['animalId'] as String?;
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          record['ear_tag'] = animalData['ear_tag'] ?? 'Unknown';
          record['breed'] = animalData['breed'] ?? '';
        } else {
          record['ear_tag'] = 'Unknown';
          record['breed'] = '';
        }
      } else {
        record['ear_tag'] = 'Unknown';
        record['breed'] = '';
      }
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> getAllBreedingRecords() async {
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(50)
        .get();
    final records = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    for (var record in records) {
      final animalId = record['animalId'] as String?;
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          record['ear_tag'] = animalData['ear_tag'] ?? 'Unknown';
          record['breed'] = animalData['breed'] ?? '';
        } else {
          record['ear_tag'] = 'Unknown';
          record['breed'] = '';
        }
      } else {
        record['ear_tag'] = 'Unknown';
        record['breed'] = '';
      }
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> getBreedingRecordsForAnimal(String animalId) async {
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('animalId', isEqualTo: animalId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>> getBreedingReportData(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    final records = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    int total = records.length;
    int heats = 0, inseminations = 0, pregnancies = 0, calvings = 0;
    for (var r in records) {
      final eventType = r['event_type'] as String?;
      switch (eventType) {
        case 'Heat Detected': heats++; break;
        case 'Inseminated': inseminations++; break;
        case 'Pregnancy Confirmed': pregnancies++; break;
        case 'Calved': calvings++; break;
      }
    }
    return {
      'total': total,
      'heats': heats,
      'inseminations': inseminations,
      'pregnancies': pregnancies,
      'calvings': calvings,
    };
  }

  // NEW: get list of breeding records for a date range
  Future<List<Map<String, dynamic>>> getBreedingRecordsForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Customers ==========
  Future<String> addCustomer(Map<String, dynamic> customer) => addDocument('customers', customer);
  Future<void> updateCustomer(String docId, Map<String, dynamic> customer) => updateDocument('customers', docId, customer);
  Future<void> deleteCustomer(String docId) => deleteDocument('customers', docId);
  Stream<QuerySnapshot> getCustomers() => getCollectionStream('customers');

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final snapshot = await _firestore
        .collection('customers')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Sales ==========
  Future<String> addSale(Map<String, dynamic> sale) => addDocument('sales', sale);
  Future<void> updateSale(String docId, Map<String, dynamic> sale) => updateDocument('sales', docId, sale);
  Future<void> deleteSale(String docId) => deleteDocument('sales', docId);
  Stream<QuerySnapshot> getSales() => getCollectionStream('sales');

  Future<List<Map<String, dynamic>>> getTodaySalesWithCustomers() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    final sales = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    final enriched = <Map<String, dynamic>>[];
    for (var sale in sales) {
      final customerId = sale['customerId'] as String?;
      String customerName = 'Unknown';
      if (customerId != null) {
        final customerDoc = await _firestore.collection('customers').doc(customerId).get();
        if (customerDoc.exists) {
          final customerData = customerDoc.data() as Map<String, dynamic>;
          customerName = customerData['name'] ?? 'Unknown';
        }
      }
      sale['customer_name'] = customerName;
      enriched.add(sale);
    }
    return enriched;
  }

  Future<Map<String, dynamic>> getTodaySalesSummary() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    double totalRevenue = 0, totalLitres = 0, totalPricePerLitre = 0;
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['total'] as num? ?? 0).toDouble();
      totalLitres += (data['quantity'] as num? ?? 0).toDouble();
      totalPricePerLitre += (data['price_per_litre'] as num? ?? 0).toDouble();
      count++;
    }
    final avgPrice = count > 0 ? totalPricePerLitre / count : 0;
    return {
      'total_revenue': totalRevenue,
      'total_litres': totalLitres,
      'avg_price': avgPrice,
    };
  }

  Future<Map<String, dynamic>> getSalesReportData(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double totalRevenue = 0, totalLitres = 0, totalPricePerLitre = 0;
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['total'] as num? ?? 0).toDouble();
      totalLitres += (data['quantity'] as num? ?? 0).toDouble();
      totalPricePerLitre += (data['price_per_litre'] as num? ?? 0).toDouble();
      count++;
    }
    final avgPrice = count > 0 ? totalPricePerLitre / count : 0;
    return {
      'total_revenue': totalRevenue,
      'total_litres': totalLitres,
      'avg_price': avgPrice,
    };
  }

  Future<double> getMonthlySales() async {
    final now = DateTime.now();
    final start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['total'] as num? ?? 0).toDouble();
    }
    return total;
  }

  // NEW: get list of sales for a date range
  Future<List<Map<String, dynamic>>> getSalesForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Feed ==========
  Future<String> addFeedItem(Map<String, dynamic> item) => addDocument('feed_inventory', item);
  Future<void> updateFeedItem(String docId, Map<String, dynamic> item) => updateDocument('feed_inventory', docId, item);
  Future<void> deleteFeedItem(String docId) => deleteDocument('feed_inventory', docId);
  Stream<QuerySnapshot> getFeedInventoryStream() => getCollectionStream('feed_inventory');

  Future<String> addFeedPurchase(Map<String, dynamic> purchase) => addDocument('feed_purchases', purchase);
  Future<String> addFeedUsage(Map<String, dynamic> usage) => addDocument('feed_usage', usage);

  Future<List<Map<String, dynamic>>> getFeedInventory() async {
    final snapshot = await _firestore
        .collection('feed_inventory')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> getFeedItem(String name) async {
    final snapshot = await _firestore
        .collection('feed_inventory')
        .where('userId', isEqualTo: userId)
        .where('name', isEqualTo: name)
        .where('deleted', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    data['id'] = snapshot.docs.first.id;
    return data;
  }

  Future<void> updateFeedQuantity(String name, double newQuantity) async {
    final snapshot = await _firestore
        .collection('feed_inventory')
        .where('userId', isEqualTo: userId)
        .where('name', isEqualTo: name)
        .where('deleted', isEqualTo: false)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await _firestore.collection('feed_inventory').doc(snapshot.docs.first.id).update({
        'quantity': newQuantity,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<double> getMonthlyFeedCost() async {
    final now = DateTime.now();
    final start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
    final snapshot = await _firestore
        .collection('feed_purchases')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['cost'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getTodayFeedUsage() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('feed_usage')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getLowStockItems() async {
    final inventory = await getFeedInventory();
    return inventory.where((item) {
      final qty = item['quantity'] as num? ?? 0;
      final threshold = item['min_threshold'] as num? ?? 0;
      return qty <= threshold;
    }).toList();
  }

  // ========== Inventory ==========
  Future<String> addInventoryItem(Map<String, dynamic> item) => addDocument('inventory', item);
  Future<void> updateInventoryItem(String docId, Map<String, dynamic> item) => updateDocument('inventory', docId, item);
  Future<void> deleteInventoryItem(String docId) => deleteDocument('inventory', docId);
  Stream<QuerySnapshot> getInventoryStream() => getCollectionStream('inventory');

  Future<String> addInventoryPurchase(Map<String, dynamic> purchase) => addDocument('inventory_purchases', purchase);

  Future<List<Map<String, dynamic>>> getMedicineInventory() async {
    final snapshot = await _firestore
        .collection('inventory')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'Medicine')
        .where('deleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getEquipmentInventory() async {
    final snapshot = await _firestore
        .collection('inventory')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'Equipment')
        .where('deleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getLowMedicineStock() async {
    final medicines = await getMedicineInventory();
    return medicines.where((item) {
      final qty = item['quantity'] as num? ?? 0;
      final threshold = item['min_threshold'] as num? ?? 0;
      return qty <= threshold;
    }).toList();
  }

  Future<void> updateInventoryQuantity(String id, double newQuantity) async {
    await _firestore.collection('inventory').doc(id).update({
      'quantity': newQuantity,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getInventoryItem(String id) async {
    final doc = await _firestore.collection('inventory').doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  // ========== Finance ==========
  Future<double> getMilkSalesForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['total'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<double> getOtherIncomeForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('other_income')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<double> getFeedCostForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    double total = 0;

    final feedPurchasesSnapshot = await _firestore
        .collection('feed_purchases')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    for (var doc in feedPurchasesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['cost'] as num? ?? 0).toDouble();
    }

    final expensesSnapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'Feed')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num? ?? 0).toDouble();
    }

    return total;
  }

  Future<double> getVetCostForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    double total = 0;

    final vetRecordsSnapshot = await _firestore
        .collection('vet_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    for (var doc in vetRecordsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['cost'] as num? ?? 0).toDouble();
    }

    final expensesSnapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'Veterinary')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num? ?? 0).toDouble();
    }

    return total;
  }

  Future<double> getLaborCostForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'Labor')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<double> getEquipmentCostForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'Equipment')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<double> getOtherExpensesForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);

    final snapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    double total = 0;
    final excludedCategories = {'Feed', 'Veterinary', 'Labor', 'Equipment'};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] as String?;
      if (category != null && !excludedCategories.contains(category)) {
        total += (data['amount'] as num? ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getExpensesListForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // NEW: get list of expenses for any date range (generalisation)
  Future<List<Map<String, dynamic>>> getExpensesForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getOtherIncomeListForMonth(DateTime startDate, DateTime endDate) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final snapshot = await _firestore
        .collection('other_income')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // NEW: get list of other income for any date range
  Future<List<Map<String, dynamic>>> getOtherIncomeForDateRange(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final snapshot = await _firestore
        .collection('other_income')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<String> addExpense(Map<String, dynamic> expense) => addDocument('expenses', expense);
  Future<String> addOtherIncome(Map<String, dynamic> income) => addDocument('other_income', income);
  Future<void> deleteExpense(String id) => deleteDocument('expenses', id);
  Future<void> deleteOtherIncome(String id) => deleteDocument('other_income', id);

  // ✅ CORRECTED: removed the call to getExpensesForMonth (no longer exists)
  Future<List<Map<String, dynamic>>> getMonthlyProfitTrend(int months) async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final month = now.month - i;
      final year = now.year;
      int yearOffset = 0;
      int adjustedMonth = month;
      if (adjustedMonth <= 0) {
        yearOffset = (adjustedMonth - 1) ~/ 12 - 1;
        adjustedMonth = ((adjustedMonth - 1) % 12) + 12;
      }
      final startDate = DateTime(year + yearOffset, adjustedMonth, 1);
      final endDate = DateTime(year + yearOffset, adjustedMonth + 1, 0);

      final income = await getMilkSalesForMonth(startDate, endDate) +
                      await getOtherIncomeForMonth(startDate, endDate);
      final expense = await getFeedCostForMonth(startDate, endDate) +
                      await getVetCostForMonth(startDate, endDate) +
                      await getLaborCostForMonth(startDate, endDate) +
                      await getEquipmentCostForMonth(startDate, endDate) +
                      await getOtherExpensesForMonth(startDate, endDate);
      final profit = income - expense;
      final monthName = DateFormat('MMM yyyy').format(startDate);
      result.add({
        'month': monthName,
        'profit': profit,
        'income': income,
        'expense': expense,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getYearlyProfitTrend(int months) async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, 1);
    final startDate = endDate.subtract(Duration(days: months * 30));

    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);

    final salesSnapshot = await _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    final incomeSnapshot = await _firestore
        .collection('other_income')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    final expensesSnapshot = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    final feedSnapshot = await _firestore
        .collection('feed_purchases')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    final vetSnapshot = await _firestore
        .collection('vet_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('deleted', isEqualTo: false)
        .get();

    final Map<String, Map<String, double>> monthlyData = {};

    void addToMonth(String date, String type, double amount) {
      final monthKey = date.substring(0, 7);
      monthlyData.putIfAbsent(monthKey, () => {
        'income': 0,
        'expense': 0,
        'feed': 0,
        'vet': 0,
        'labor': 0,
        'equipment': 0,
        'other_expense': 0,
      });
      if (type == 'income') {
        monthlyData[monthKey]!['income'] = (monthlyData[monthKey]!['income'] ?? 0) + amount;
      } else if (type == 'expense') {
        monthlyData[monthKey]!['expense'] = (monthlyData[monthKey]!['expense'] ?? 0) + amount;
      }
    }

    for (final doc in salesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String;
      final amount = (data['total'] as num? ?? 0).toDouble();
      addToMonth(date, 'income', amount);
    }

    for (final doc in incomeSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String;
      final amount = (data['amount'] as num? ?? 0).toDouble();
      addToMonth(date, 'income', amount);
    }

    final excludedCategories = {'Feed', 'Veterinary', 'Labor', 'Equipment'};
    for (final doc in expensesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String;
      final amount = (data['amount'] as num? ?? 0).toDouble();
      final category = data['category'] as String?;
      if (category == null) continue;
      if (!excludedCategories.contains(category)) {
        addToMonth(date, 'expense', amount);
      }
    }

    for (final doc in feedSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String;
      final amount = (data['cost'] as num? ?? 0).toDouble();
      addToMonth(date, 'expense', amount);
    }

    for (final doc in vetSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String;
      final amount = (data['cost'] as num? ?? 0).toDouble();
      addToMonth(date, 'expense', amount);
    }

    final List<Map<String, dynamic>> result = [];
    final nowMonth = DateTime(now.year, now.month);
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);
      final data = monthlyData[monthKey];
      if (data == null) {
        result.add({
          'month': DateFormat('MMM yyyy').format(month),
          'profit': 0,
          'income': 0,
          'expense': 0,
        });
      } else {
        final income = data['income'] ?? 0;
        final expense = data['expense'] ?? 0;
        result.add({
          'month': DateFormat('MMM yyyy').format(month),
          'profit': income - expense,
          'income': income,
          'expense': expense,
        });
      }
    }
    return result;
  }

  // ========== Notifications ==========
  Future<String> addNotification(Map<String, dynamic> notification) async {
    final docId = await addDocument('notifications', notification);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sendPushNotification(
        user.uid,
        notification['title'] ?? '',
        notification['message'] ?? '',
        notification['type'] ?? 'general',
      );
    }

    return docId;
  }

  Future<void> updateNotification(String docId, Map<String, dynamic> notification) => updateDocument('notifications', docId, notification);
  Future<void> deleteNotification(String docId) => deleteDocument('notifications', docId);
  Stream<QuerySnapshot> getNotificationsStream() => getCollectionStream('notifications');

  Future<List<Map<String, dynamic>>> getActiveNotifications() async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> markNotificationAsRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({
      'is_read': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'is_read': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<int> getUnreadNotificationCount() async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  // ========== Users ==========
  Future<String> addUser(Map<String, dynamic> user) => addDocument('users', user);
  Future<void> updateUser(String docId, Map<String, dynamic> user) => updateDocument('users', docId, user);
  Future<void> deleteUser(String docId) => deleteDocument('users', docId);
  Stream<QuerySnapshot> getUsersStream() => getCollectionStream('users');

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ========== Today's Activities ==========
  Future<List<Map<String, dynamic>>> getTodayActivities() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final activities = <Map<String, dynamic>>[];

    final calvingSnapshot = await _firestore
        .collection('breeding_records')
        .where('userId', isEqualTo: userId)
        .where('event_type', isEqualTo: 'Expected Calving')
        .where('date', isGreaterThanOrEqualTo: today)
        .where('deleted', isEqualTo: false)
        .orderBy('date')
        .limit(3)
        .get();
    for (var doc in calvingSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final animalId = data['animalId'] as String?;
      String earTag = 'Unknown';
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          earTag = animalData['ear_tag'] ?? 'Unknown';
        }
      }
      activities.add({
        'title': 'Calving expected for Cow #$earTag',
        'subtitle': 'Due on ${data['date']}',
        'status': 'Upcoming',
        'statusColor': '#3B82F6',
        'statusBg': '#E0F2FE',
        'icon': 'pregnant_woman',
      });
    }

    final lowFeed = await getLowStockItems();
    for (var item in lowFeed) {
      activities.add({
        'title': 'Low feed: ${item['name']}',
        'subtitle': 'Only ${item['quantity']} ${item['unit']} left',
        'status': 'Alert',
        'statusColor': '#F59E0B',
        'statusBg': '#FFF4E5',
        'icon': 'warning_amber',
      });
    }

    final milkSnapshot = await _firestore
        .collection('milk_records')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    final milkMap = <String, double>{};
    for (var doc in milkSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final animalId = data['animalId'] as String?;
      if (animalId != null) {
        final total = (data['morning'] as num? ?? 0) + (data['midday'] as num? ?? 0) + (data['evening'] as num? ?? 0);
        milkMap[animalId] = (milkMap[animalId] ?? 0) + total;
      }
    }
    final sorted = milkMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (int i = 0; i < sorted.length && i < 3; i++) {
      final entry = sorted[i];
      final animalDoc = await _firestore.collection('animals').doc(entry.key).get();
      if (animalDoc.exists) {
        final animalData = animalDoc.data() as Map<String, dynamic>;
        final earTag = animalData['ear_tag'] ?? 'Unknown';
        activities.add({
          'title': '$earTag produced ${entry.value.toStringAsFixed(0)}L today',
          'subtitle': 'Milk recorded',
          'status': 'Completed',
          'statusColor': '#2E7D32',
          'statusBg': '#E8F5E9',
          'icon': 'water_drop',
        });
      }
    }

    final healthSnapshot = await _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .where('next_due', isEqualTo: today)
        .where('deleted', isEqualTo: false)
        .get();
    for (var doc in healthSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final animalId = data['animalId'] as String?;
      String earTag = 'Unknown';
      if (animalId != null) {
        final animalDoc = await _firestore.collection('animals').doc(animalId).get();
        if (animalDoc.exists) {
          final animalData = animalDoc.data() as Map<String, dynamic>;
          earTag = animalData['ear_tag'] ?? 'Unknown';
        }
      }
      activities.add({
        'title': '${data['type']} due for Cow #$earTag',
        'subtitle': 'Scheduled for today',
        'status': 'Pending',
        'statusColor': '#F59E0B',
        'statusBg': '#FFF4E5',
        'icon': 'vaccines',
      });
    }

    activities.sort((a, b) {
      final priority = {'Pending': 0, 'Upcoming': 1, 'Alert': 2, 'Completed': 3};
      return (priority[a['status']] ?? 4).compareTo(priority[b['status']] ?? 4);
    });

    return activities;
  }

  Future<void> deleteTodayActivities() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _firestore
        .collection('activities')
        .where('date', isEqualTo: today)
        .get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ========== Export all data as CSV ==========
  Future<String> exportAllDataAsCsv() async {
    final tables = [
      'animals', 'milk_records', 'health_records', 'breeding_records',
      'customers', 'sales', 'feed_inventory', 'feed_usage', 'feed_purchases',
      'expenses', 'other_income', 'vet_records', 'inventory',
      'inventory_purchases', 'notifications', 'users'
    ];
    final Map<String, String> csvData = {};

    for (final table in tables) {
      final snapshot = await _firestore
          .collection(table)
          .where('userId', isEqualTo: userId)
          .get();
      if (snapshot.docs.isEmpty) {
        csvData[table] = 'No data';
        continue;
      }
      final csvRows = <List<dynamic>>[];
      final headers = snapshot.docs.first.data().keys.toList();
      csvRows.add(headers);
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        csvRows.add(headers.map((h) => data[h] ?? '').toList());
      }
      final csvString = const ListToCsvConverter().convert(csvRows);
      csvData[table] = csvString;
    }

    final buffer = StringBuffer();
    for (final entry in csvData.entries) {
      buffer.writeln('===== TABLE: ${entry.key} =====');
      buffer.writeln(entry.value);
      buffer.writeln('\n');
    }
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final file = File(p.join(tempDir.path, 'ithare_farm_backup_$timestamp.csv'));
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // ========== Clear all user data ==========
  Future<void> clearAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final uid = user.uid;

    final collections = [
      'animals',
      'milk_records',
      'health_records',
      'breeding_records',
      'customers',
      'sales',
      'feed_inventory',
      'feed_usage',
      'feed_purchases',
      'expenses',
      'other_income',
      'vet_records',
      'inventory',
      'inventory_purchases',
      'notifications',
    ];

    for (final collection in collections) {
      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isEmpty) continue;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ========== Helper: Send push notification via Render server ==========
  Future<void> _sendPushNotification(String userId, String title, String message, String type) async {
    const String serverUrl = 'https://itharefarm-1.onrender.com/send-push';

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent to server');
      } else {
        print('❌ Failed to send push: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending push request: $e');
    }
  }
}