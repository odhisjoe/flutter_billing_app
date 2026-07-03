import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? address;
  final int loyaltyPoints;
  final double totalSpent;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    int? loyaltyPoints,
    double? totalSpent,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phoneNumber, email, address, loyaltyPoints, totalSpent, createdAt];
}
