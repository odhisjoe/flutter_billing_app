import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/pin_encryption_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final PinEncryptionService _encryptionService;

  AuthRepositoryImpl({PinEncryptionService? encryptionService})
      : _encryptionService = encryptionService ?? PinEncryptionService();

  @override
  Future<Either<Failure, User>> login(String pin, UserRole role) async {
    try {
      final box = HiveDatabase.usersBox;
      final users = box.values.where((u) => u.isActive).toList();

      UserModel? matched;
      for (final u in users.cast<UserModel?>()) {
        if (u!.role != role) continue;
        if (u.pinHashVersion < 2) {
          if (u.pin == pin) {
            matched = u;
            break;
          }
        } else {
          if (_encryptionService.verify(pin, u.pin)) {
            matched = u;
            break;
          }
        }
      }

      if (matched == null) {
        return Left(CacheFailure('Invalid PIN or role'));
      }

      final encrypted = _encryptionService.encryptPin(pin);
      UserModel result = matched;
      if (matched.pinHashVersion < 2 || matched.pin != encrypted) {
        final migrated = UserModel.fromEntity(matched.copyWith(
          pin: encrypted,
          pinHashVersion: 2,
        ));
        await HiveDatabase.usersBox.put(migrated.id, migrated);
        result = HiveDatabase.usersBox.get(matched.id) ?? migrated;
      }

      await HiveDatabase.settingsBox.put('current_user_id', matched.id);
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await HiveDatabase.settingsBox.delete('current_user_id');
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final userId = HiveDatabase.settingsBox.get('current_user_id') as String?;
      if (userId == null) return const Right(null);
      final user = HiveDatabase.usersBox.get(userId);
      return Right(user);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveUser(User user) async {
    try {
      final model = UserModel(
        id: user.id,
        name: user.name,
        pin: _encryptionService.encryptPin(user.pin),
        role: user.role,
        isActive: user.isActive,
        pinHashVersion: 2,
        hasCompletedSetup: user.hasCompletedSetup,
        previousPin: user.previousPin,
        isPinReset: user.isPinReset,
      );
      await HiveDatabase.usersBox.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<User>>> getAllUsers() async {
    try {
      final users = HiveDatabase.usersBox.values.toList();
      return Right(users);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      await HiveDatabase.usersBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUser(User user) async {
    try {
      final model = UserModel(
        id: user.id,
        name: user.name,
        pin: _encryptionService.encryptPin(user.pin),
        role: user.role,
        isActive: user.isActive,
        pinHashVersion: 2,
        hasCompletedSetup: user.hasCompletedSetup,
        previousPin: user.previousPin,
        isPinReset: user.isPinReset,
      );
      await HiveDatabase.usersBox.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasAdmin() async {
    try {
      final users = HiveDatabase.usersBox.values;
      return Right(users.any((u) => u.role == UserRole.admin));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
