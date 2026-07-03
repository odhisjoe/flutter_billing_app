import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/user.dart';

enum EmployeeStatus { initial, loading, loaded, error }

class EmployeeState extends Equatable {
  final EmployeeStatus status;
  final List<User> employees;
  final String? message;

  const EmployeeState({
    this.status = EmployeeStatus.initial,
    this.employees = const [],
    this.message,
  });

  EmployeeState copyWith({
    EmployeeStatus? status,
    List<User>? employees,
    String? message,
  }) {
    return EmployeeState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, employees, message];
}
