import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final int stock;
  final String? category;
  final String? imageUrl;
  final String? sku;
  final double buyingPrice;
  final String? supplier;
  final int minStockLevel;
  final String? assignedTo;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.category = 'General',
    this.imageUrl = '',
    this.sku,
    this.buyingPrice = 0,
    this.supplier,
    this.minStockLevel = 0,
    this.assignedTo,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    String? category,
    String? imageUrl,
    String? sku,
    double? buyingPrice,
    String? supplier,
    int? minStockLevel,
    String? assignedTo,
    bool clearAssignedTo = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      supplier: supplier ?? this.supplier,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, barcode, price, stock, category, imageUrl, sku, buyingPrice, supplier, minStockLevel, assignedTo];
}
