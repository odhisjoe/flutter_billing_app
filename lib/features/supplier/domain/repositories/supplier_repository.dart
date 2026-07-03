import '../entities/supplier.dart';

abstract class SupplierRepository {
  List<Supplier> getAll();
  void add(Supplier supplier);
  void update(Supplier supplier);
  void delete(String id);
  List<Supplier> search(String query);
}
