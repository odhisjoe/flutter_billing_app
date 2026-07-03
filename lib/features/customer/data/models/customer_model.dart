import 'package:hive/hive.dart';
import '../../domain/entities/customer.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 5)
class CustomerModel extends Customer {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String phoneNumber;
  @override
  @HiveField(3)
  final String? email;
  @override
  @HiveField(4)
  final String? address;
  @override
  @HiveField(5)
  final int loyaltyPoints;
  @override
  @HiveField(6)
  final double totalSpent;
  @override
  @HiveField(7)
  final DateTime createdAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    required this.createdAt,
  }) : super(
          id: id,
          name: name,
          phoneNumber: phoneNumber,
          email: email,
          address: address,
          loyaltyPoints: loyaltyPoints,
          totalSpent: totalSpent,
          createdAt: createdAt,
        );

  factory CustomerModel.fromEntity(Customer customer) {
    return CustomerModel(
      id: customer.id,
      name: customer.name,
      phoneNumber: customer.phoneNumber,
      email: customer.email,
      address: customer.address,
      loyaltyPoints: customer.loyaltyPoints,
      totalSpent: customer.totalSpent,
      createdAt: customer.createdAt,
    );
  }

  Customer toEntity() {
    return Customer(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      address: address,
      loyaltyPoints: loyaltyPoints,
      totalSpent: totalSpent,
      createdAt: createdAt,
    );
  }
}
