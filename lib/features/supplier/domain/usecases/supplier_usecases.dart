import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class GetAllSuppliersUseCase {
  final SupplierRepository repository;
  GetAllSuppliersUseCase(this.repository);
  List<Supplier> call() => repository.getAll();
}

class AddSupplierUseCase {
  final SupplierRepository repository;
  AddSupplierUseCase(this.repository);
  Future<void> call(Supplier supplier) async => repository.add(supplier);
}

class UpdateSupplierUseCase {
  final SupplierRepository repository;
  UpdateSupplierUseCase(this.repository);
  Future<void> call(Supplier supplier) async => repository.update(supplier);
}

class DeleteSupplierUseCase {
  final SupplierRepository repository;
  DeleteSupplierUseCase(this.repository);
  Future<void> call(String id) async => repository.delete(id);
}

class SearchSuppliersUseCase {
  final SupplierRepository repository;
  SearchSuppliersUseCase(this.repository);
  List<Supplier> call(String query) => repository.search(query);
}
