import 'package:billing_app/core/data/hive_database.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../models/supplier_model.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  @override
  List<Supplier> getAll() {
    return HiveDatabase.supplierBox.values
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  void add(Supplier supplier) {
    final model = SupplierModel.fromEntity(supplier);
    HiveDatabase.supplierBox.put(model.id, model);
  }

  @override
  void update(Supplier supplier) {
    final model = SupplierModel.fromEntity(supplier);
    HiveDatabase.supplierBox.put(model.id, model);
  }

  @override
  void delete(String id) {
    HiveDatabase.supplierBox.delete(id);
  }

  @override
  List<Supplier> search(String query) {
    final q = query.toLowerCase();
    return getAll().where((s) =>
        s.name.toLowerCase().contains(q) || s.phoneNumber.contains(q)).toList();
  }
}
