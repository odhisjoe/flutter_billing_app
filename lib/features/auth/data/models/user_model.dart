import 'package:hive/hive.dart';
import '../../domain/entities/user.dart';

part 'user_model.g.dart';

@HiveType(typeId: 7)
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.pin,
    required super.role,
    super.isActive = true,
    super.pinHashVersion = 2,
    super.hasCompletedSetup = false,
    super.previousPin,
    super.isPinReset = false,
  });

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      pin: user.pin,
      role: user.role,
      isActive: user.isActive,
      pinHashVersion: user.pinHashVersion,
      hasCompletedSetup: user.hasCompletedSetup,
      previousPin: user.previousPin,
      isPinReset: user.isPinReset,
    );
  }

  User toEntity() {
    return User(
      id: id,
      name: name,
      pin: pin,
      role: role,
      isActive: isActive,
      pinHashVersion: pinHashVersion,
      hasCompletedSetup: hasCompletedSetup,
      previousPin: previousPin,
      isPinReset: isPinReset,
    );
  }
}
