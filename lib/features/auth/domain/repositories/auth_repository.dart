import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  // PIN login (cashiers)
  Future<Either<Failure, User>> login(String pin, UserRole role);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User?>> getCurrentUser();

  // CRUD
  Future<Either<Failure, void>> saveUser(User user);
  Future<Either<Failure, List<User>>> getAllUsers();
  Future<Either<Failure, void>> deleteUser(String id);
  Future<Either<Failure, void>> updateUser(User user);
  Future<Either<Failure, bool>> hasAdmin();
}
