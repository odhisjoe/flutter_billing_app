import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class AddCustomerUseCase {
  final CustomerRepository repository;
  AddCustomerUseCase(this.repository);
  Future<void> call(Customer customer) => repository.addCustomer(customer);
}

class UpdateCustomerUseCase {
  final CustomerRepository repository;
  UpdateCustomerUseCase(this.repository);
  Future<void> call(Customer customer) => repository.updateCustomer(customer);
}

class DeleteCustomerUseCase {
  final CustomerRepository repository;
  DeleteCustomerUseCase(this.repository);
  Future<void> call(String id) => repository.deleteCustomer(id);
}

class GetCustomerByPhoneUseCase {
  final CustomerRepository repository;
  GetCustomerByPhoneUseCase(this.repository);
  Customer? call(String phone) => repository.getCustomerByPhone(phone);
}

class SearchCustomersUseCase {
  final CustomerRepository repository;
  SearchCustomersUseCase(this.repository);
  List<Customer> call(String query) => repository.searchCustomers(query);
}

class GetAllCustomersUseCase {
  final CustomerRepository repository;
  GetAllCustomersUseCase(this.repository);
  List<Customer> call() => repository.getAllCustomers();
}
