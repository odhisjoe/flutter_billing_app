import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase implements UseCase<User, LoginParams> {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  @override
  Future<Either<Failure, User>> call(LoginParams params) {
    return repository.login(params.pin, params.role);
  }
}

class LoginParams {
  final String pin;
  final UserRole role;
  const LoginParams({required this.pin, required this.role});
}

class LogoutUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;
  LogoutUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.logout();
  }
}

class GetCurrentUserUseCase implements UseCase<User?, NoParams> {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, User?>> call(NoParams params) {
    return repository.getCurrentUser();
  }
}

class GetAllUsersUseCase implements UseCase<List<User>, NoParams> {
  final AuthRepository repository;
  GetAllUsersUseCase(this.repository);

  @override
  Future<Either<Failure, List<User>>> call(NoParams params) {
    return repository.getAllUsers();
  }
}

class SaveUserUseCase implements UseCase<void, User> {
  final AuthRepository repository;
  SaveUserUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(User params) {
    return repository.saveUser(params);
  }
}

class DeleteUserUseCase implements UseCase<void, String> {
  final AuthRepository repository;
  DeleteUserUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteUser(params);
  }
}

class UpdateUserUseCase implements UseCase<void, User> {
  final AuthRepository repository;
  UpdateUserUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(User params) {
    return repository.updateUser(params);
  }
}

class HasAdminUseCase implements UseCase<bool, NoParams> {
  final AuthRepository repository;
  HasAdminUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return repository.hasAdmin();
  }
}
