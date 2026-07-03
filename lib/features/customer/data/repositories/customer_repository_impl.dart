import '../../../../core/data/hive_database.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  @override
  Future<void> addCustomer(Customer customer) async {
    final model = CustomerModel.fromEntity(customer);
    await HiveDatabase.customerBox.put(model.id, model);
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final model = CustomerModel.fromEntity(customer);
    await HiveDatabase.customerBox.put(model.id, model);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await HiveDatabase.customerBox.delete(id);
  }

  @override
  Customer? getCustomer(String id) {
    final model = HiveDatabase.customerBox.get(id);
    return model?.toEntity();
  }

  @override
  Customer? getCustomerByPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final model = HiveDatabase.customerBox.values.cast<CustomerModel?>().firstWhere(
      (m) {
        if (m == null) return false;
        return m.phoneNumber.replaceAll(RegExp(r'\s+'), '') == cleaned;
      },
      orElse: () => null,
    );
    return model?.toEntity();
  }

  @override
  List<Customer> getAllCustomers() {
    return HiveDatabase.customerBox.values
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  List<Customer> searchCustomers(String query) {
    final q = query.toLowerCase();
    return HiveDatabase.customerBox.values
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.phoneNumber.replaceAll(RegExp(r'\s+'), '').contains(q.replaceAll(RegExp(r'\s+'), '')))
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
