import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final double totalPurchases;
  final double amountPaid;

  double get balance => totalPurchases - amountPaid;

  const Supplier({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    required this.createdAt,
    this.totalPurchases = 0,
    this.amountPaid = 0,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    DateTime? createdAt,
    double? totalPurchases,
    double? amountPaid,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      amountPaid: amountPaid ?? this.amountPaid,
    );
  }

  @override
  List<Object?> get props => [id, name, phoneNumber, email, address, createdAt, totalPurchases, amountPaid];
}
