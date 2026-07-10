class HealthRecord {
  final String? id;
  final String animalId;
  final String type;
  final String date;
  final String? description;
  final String? nextDue;
  final String? notes;

  HealthRecord({
    this.id,
    required this.animalId,
    required this.type,
    required this.date,
    this.description,
    this.nextDue,
    this.notes,
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as String?,
      animalId: map['animalId'] as String,
      type: map['type'] ?? '',
      date: map['date'] ?? '',
      description: map['description'],
      nextDue: map['next_due'],
      notes: map['notes'],
    );
  }
}