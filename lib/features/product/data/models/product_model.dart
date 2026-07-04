import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.barcode,
    required super.price,
    required super.stock,
    String? category,
    String? imageUrl,
    super.sku,
    super.buyingPrice,
    super.supplier,
    super.minStockLevel,
    super.assignedTo,
  }) : super(
          category: category ?? 'General',
          imageUrl: imageUrl ?? '',
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
