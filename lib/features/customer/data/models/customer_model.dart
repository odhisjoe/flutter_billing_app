import 'package:hive/hive.dart';
import '../../domain/entities/customer.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 5)
class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.phoneNumber,
    super.email,
    super.address,
    super.loyaltyPoints = 0,
    super.totalSpent = 0,
    required super.createdAt,
  });

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
