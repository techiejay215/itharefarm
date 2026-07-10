class BreedingRecord {
  final String? id;
  final String animalId;
  final String eventType;
  final String date;
  final String? notes;

  BreedingRecord({
    this.id,
    required this.animalId,
    required this.eventType,
    required this.date,
    this.notes,
  });

  factory BreedingRecord.fromMap(Map<String, dynamic> map) {
    return BreedingRecord(
      id: map['id'] as String?,
      animalId: map['animalId'] as String,
      eventType: map['event_type'] ?? '',
      date: map['date'] ?? '',
      notes: map['notes'],
    );
  }
}