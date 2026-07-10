class Animal {
  final String? id;
  final String earTag;
  final String breed;
  final String status;
  final String? name;
  final String? animalType;
  final String? lastCalving;
  final String? motherName;    // ← new
  final String? dateOfBirth;   // ← new (ISO date string)

  Animal({
    this.id,
    required this.earTag,
    required this.breed,
    required this.status,
    this.name,
    this.animalType,
    this.lastCalving,
    this.motherName,
    this.dateOfBirth,
  });

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'] as String?,
      earTag: map['ear_tag'] ?? '',
      breed: map['breed'] ?? '',
      status: map['status'] ?? '',
      name: map['name'],
      animalType: map['animal_type'],
      lastCalving: map['last_calving'],
      motherName: map['mother_name'],          // ← new
      dateOfBirth: map['date_of_birth'],       // ← new
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ear_tag': earTag,
      'breed': breed,
      'status': status,
      'name': name,
      'animal_type': animalType,
      'last_calving': lastCalving,
      'mother_name': motherName,               // ← new
      'date_of_birth': dateOfBirth,            // ← new
    };
  }

  String getDisplayName() {
    if (name != null && name!.isNotEmpty) return name!;
    return '$animalType #$earTag';
  }

  Map<String, String> getStatusStyle() {
    switch (status) {
      case 'Lactating':
        return {'bg': '#E8F5E9', 'text': '#2E7D32'};
      case 'Pregnant':
        return {'bg': '#FFF8E1', 'text': '#F9A825'};
      case 'Dry':
        return {'bg': '#F5F5F5', 'text': '#757575'};
      case 'Calf':
        return {'bg': '#E3F2FD', 'text': '#1976D2'};
      case 'Sold':
        return {'bg': '#FFEBEE', 'text': '#D32F2F'};
      default:
        return {'bg': '#E8F5E9', 'text': '#2E7D32'};
    }
  }
}