import 'package:equatable/equatable.dart';
import '../../domain/entities/supplier.dart';

class SupplierState extends Equatable {
  final List<Supplier> suppliers;
  final bool isLoading;

  const SupplierState({
    this.suppliers = const [],
    this.isLoading = false,
  });

  SupplierState copyWith({
    List<Supplier>? suppliers,
    bool? isLoading,
  }) {
    return SupplierState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [suppliers, isLoading];
}
