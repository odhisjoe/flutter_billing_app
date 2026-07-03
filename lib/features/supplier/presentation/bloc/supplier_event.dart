import 'package:equatable/equatable.dart';
import '../../domain/entities/supplier.dart';

abstract class SupplierEvent extends Equatable {
  const SupplierEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliers extends SupplierEvent {
  const LoadSuppliers();
}

class AddSupplier extends SupplierEvent {
  final Supplier supplier;
  const AddSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class UpdateSupplier extends SupplierEvent {
  final Supplier supplier;
  const UpdateSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class DeleteSupplier extends SupplierEvent {
  final String id;
  const DeleteSupplier(this.id);
  @override
  List<Object?> get props => [id];
}

class SearchSuppliers extends SupplierEvent {
  final String query;
  const SearchSuppliers(this.query);
  @override
  List<Object?> get props => [query];
}
