import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import 'employee_event.dart';
import 'employee_state.dart';

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  final AuthRepository _repository;

  EmployeeBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepositoryImpl(),
        super(const EmployeeState()) {
    on<LoadEmployees>(_onLoadEmployees);
    on<AddEmployee>(_onAddEmployee);
    on<UpdateEmployee>(_onUpdateEmployee);
    on<ToggleEmployeeActive>(_onToggleActive);
    on<DeleteEmployee>(_onDeleteEmployee);
  }

  Future<void> _onLoadEmployees(
      LoadEmployees event, Emitter<EmployeeState> emit) async {
    emit(state.copyWith(status: EmployeeStatus.loading));
    final result = await _repository.getAllUsers();
    result.fold(
      (failure) => emit(state.copyWith(
          status: EmployeeStatus.error, message: failure.message)),
      (users) => emit(state.copyWith(
          status: EmployeeStatus.loaded, employees: users)),
    );
  }

  Future<void> _onAddEmployee(
      AddEmployee event, Emitter<EmployeeState> emit) async {
    final user = User(
      id: const Uuid().v4(),
      name: event.name,
      pin: event.pin,
      role: event.role,
    );
    final result = await _repository.saveUser(user);
    result.fold(
      (failure) => emit(state.copyWith(
          status: EmployeeStatus.error, message: failure.message)),
      (_) => add(const LoadEmployees()),
    );
  }

  Future<void> _onUpdateEmployee(
      UpdateEmployee event, Emitter<EmployeeState> emit) async {
    final result = await _repository.updateUser(event.user);
    result.fold(
      (failure) => emit(state.copyWith(
          status: EmployeeStatus.error, message: failure.message)),
      (_) => add(const LoadEmployees()),
    );
  }

  Future<void> _onToggleActive(
      ToggleEmployeeActive event, Emitter<EmployeeState> emit) async {
    final current = state.employees.where((u) => u.id == event.userId).firstOrNull;
    if (current == null) return;
    final result = await _repository.updateUser(
        current.copyWith(isActive: !current.isActive));
    result.fold(
      (failure) => emit(state.copyWith(
          status: EmployeeStatus.error, message: failure.message)),
      (_) => add(const LoadEmployees()),
    );
  }

  Future<void> _onDeleteEmployee(
      DeleteEmployee event, Emitter<EmployeeState> emit) async {
    final result = await _repository.deleteUser(event.userId);
    result.fold(
      (failure) => emit(state.copyWith(
          status: EmployeeStatus.error, message: failure.message)),
      (_) => add(const LoadEmployees()),
    );
  }
}
