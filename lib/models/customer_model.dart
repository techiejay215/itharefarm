class Customer {
  final String? id;
  final String name;
  final String? phone;
  final String? location;
  final double defaultPrice;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.location,
    required this.defaultPrice,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String?,
      name: map['name'] ?? '',
      phone: map['phone'],
      location: map['location'],
      defaultPrice: (map['default_price'] as num?)?.toDouble() ?? 0,
    );
  }
}