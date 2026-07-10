class Sale {
  final String? id;
  final String customerId;
  final double quantity;
  final double pricePerLitre;
  final double total;
  final String paymentStatus;
  final String date;

  Sale({
    this.id,
    required this.customerId,
    required this.quantity,
    required this.pricePerLitre,
    required this.total,
    required this.paymentStatus,
    required this.date,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String?,
      customerId: map['customerId'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      pricePerLitre: (map['price_per_litre'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      paymentStatus: map['payment_status'] ?? '',
      date: map['date'] ?? '',
    );
  }
}