import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';

class CustomerState extends Equatable {
  final List<Customer> customers;
  final bool isLoading;

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
  });

  CustomerState copyWith({
    List<Customer>? customers,
    bool? isLoading,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [customers, isLoading];
}
