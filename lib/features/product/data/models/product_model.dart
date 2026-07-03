import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final int stock;
  @override
  @HiveField(5)
  final String? category;
  @override
  @HiveField(6)
  final String? imageUrl;
  @override
  @HiveField(7)
  final String? sku;
  @override
  @HiveField(8)
  final double buyingPrice;
  @override
  @HiveField(9)
  final String? supplier;
  @override
  @HiveField(10)
  final int minStockLevel;
  @override
  @HiveField(11)
  final String? assignedTo;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.category,
    this.imageUrl,
    this.sku,
    this.buyingPrice = 0,
    this.supplier,
    this.minStockLevel = 0,
    this.assignedTo,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          category: category ?? 'General',
          imageUrl: imageUrl ?? '',
          sku: sku,
          buyingPrice: buyingPrice,
          supplier: supplier,
          minStockLevel: minStockLevel,
          assignedTo: assignedTo,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      category: product.category,
      imageUrl: product.imageUrl,
      sku: product.sku,
      buyingPrice: product.buyingPrice,
      supplier: product.supplier,
      minStockLevel: product.minStockLevel,
      assignedTo: product.assignedTo,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      category: category ?? 'General',
      imageUrl: imageUrl ?? '',
      sku: sku,
      buyingPrice: buyingPrice,
      supplier: supplier,
      minStockLevel: minStockLevel,
      assignedTo: assignedTo,
    );
  }
}
