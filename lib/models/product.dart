class Product {
  final int? id;
  final String name;
  final double rate;
  final String? emoji;
  final String? imagePath; // Real picture save karne ke liye

  Product({
    this.id,
    required this.name,
    required this.rate,
    this.emoji,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'emoji': emoji,
      'imagePath': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      rate: (map['rate'] ?? 0.0).toDouble(),
      emoji: map['emoji'],
      imagePath: map['imagePath'],
    );
  }
}
