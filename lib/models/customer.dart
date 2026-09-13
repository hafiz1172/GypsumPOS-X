class Customer {
  final int? id;
  final String name;
  final String phone;
  final double totalDue; // Kul kitna baqaya hai

  Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.totalDue = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'totalDue': totalDue,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'] ?? '',
      totalDue: (map['totalDue'] ?? 0.0).toDouble(),
    );
  }
}
