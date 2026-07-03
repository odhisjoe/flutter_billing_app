import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<void> addCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
  Customer? getCustomer(String id);
  Customer? getCustomerByPhone(String phone);
  List<Customer> getAllCustomers();
  List<Customer> searchCustomers(String query);
}
