import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/user.dart';

abstract class EmployeeEvent extends Equatable {
  const EmployeeEvent();

  @override
  List<Object?> get props => [];
}

class LoadEmployees extends EmployeeEvent {
  const LoadEmployees();
}

class AddEmployee extends EmployeeEvent {
  final String name;
  final String pin;
  final UserRole role;

  const AddEmployee({
    required this.name,
    required this.pin,
    required this.role,
  });

  @override
  List<Object?> get props => [name, pin, role];
}

class UpdateEmployee extends EmployeeEvent {
  final User user;

  const UpdateEmployee({required this.user});

  @override
  List<Object?> get props => [user];
}

class ToggleEmployeeActive extends EmployeeEvent {
  final String userId;

  const ToggleEmployeeActive({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class DeleteEmployee extends EmployeeEvent {
  final String userId;

  const DeleteEmployee({required this.userId});

  @override
  List<Object?> get props => [userId];
}
