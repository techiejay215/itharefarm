class MilkRecord {
  final String? id;
  final String animalId;
  final String date;
  final double morning;
  final double midday;
  final double evening;

  MilkRecord({
    this.id,
    required this.animalId,
    required this.date,
    required this.morning,
    required this.midday,
    required this.evening,
  });

  factory MilkRecord.fromMap(Map<String, dynamic> map) {
    return MilkRecord(
      id: map['id'] as String?,
      animalId: map['animalId'] as String,
      date: map['date'] ?? '',
      morning: (map['morning'] as num?)?.toDouble() ?? 0,
      midday: (map['midday'] as num?)?.toDouble() ?? 0,
      evening: (map['evening'] as num?)?.toDouble() ?? 0,
    );
  }

  double get total => morning + midday + evening;
}