import 'package:flutter_bloc/flutter_bloc.dart';
import 'customer_event.dart';
import 'customer_state.dart';
import '../../domain/usecases/customer_usecases.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final GetAllCustomersUseCase getAllCustomersUseCase;
  final AddCustomerUseCase addCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;
  final DeleteCustomerUseCase deleteCustomerUseCase;
  final SearchCustomersUseCase searchCustomersUseCase;

  CustomerBloc({
    required this.getAllCustomersUseCase,
    required this.addCustomerUseCase,
    required this.updateCustomerUseCase,
    required this.deleteCustomerUseCase,
    required this.searchCustomersUseCase,
  }) : super(const CustomerState()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
    on<SearchCustomers>(_onSearchCustomers);
  }

  void _onLoadCustomers(LoadCustomers event, Emitter<CustomerState> emit) {
    final customers = getAllCustomersUseCase();
    emit(CustomerState(customers: customers));
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<CustomerState> emit) async {
    await addCustomerUseCase(event.customer);
    add(const LoadCustomers());
  }

  Future<void> _onUpdateCustomer(UpdateCustomer event, Emitter<CustomerState> emit) async {
    await updateCustomerUseCase(event.customer);
    add(const LoadCustomers());
  }

  Future<void> _onDeleteCustomer(DeleteCustomer event, Emitter<CustomerState> emit) async {
    await deleteCustomerUseCase(event.id);
    add(const LoadCustomers());
  }

  void _onSearchCustomers(SearchCustomers event, Emitter<CustomerState> emit) {
    final customers = searchCustomersUseCase(event.query);
    emit(CustomerState(customers: customers));
  }
}
