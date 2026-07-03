import 'package:hive/hive.dart';
import '../../domain/entities/supplier.dart';

part 'supplier_model.g.dart';

@HiveType(typeId: 6)
class SupplierModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phoneNumber;

  @HiveField(3)
  final String? email;

  @HiveField(4)
  final String? address;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final double totalPurchases;

  @HiveField(7)
  final double amountPaid;

  SupplierModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    required this.createdAt,
    this.totalPurchases = 0,
    this.amountPaid = 0,
  });

  factory SupplierModel.fromEntity(Supplier supplier) {
    return SupplierModel(
      id: supplier.id,
      name: supplier.name,
      phoneNumber: supplier.phoneNumber,
      email: supplier.email,
      address: supplier.address,
      createdAt: supplier.createdAt,
      totalPurchases: supplier.totalPurchases,
      amountPaid: supplier.amountPaid,
    );
  }

  Supplier toEntity() {
    return Supplier(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      address: address,
      createdAt: createdAt,
      totalPurchases: totalPurchases,
      amountPaid: amountPaid,
    );
  }
}
