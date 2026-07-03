import 'package:hive/hive.dart';
import '../../domain/entities/user.dart';

part 'user_model.g.dart';

@HiveType(typeId: 7)
class UserModel extends User {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String pin;
  @override
  @HiveField(3)
  final UserRole role;
  @override
  @HiveField(4)
  final bool isActive;
  @override
  @HiveField(5)
  final int pinHashVersion;
  @override
  @HiveField(6)
  final bool hasCompletedSetup;
  @override
  @HiveField(7)
  final String? previousPin;
  @override
  @HiveField(8, defaultValue: false)
  final bool isPinReset;

  const UserModel({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.isActive = true,
    this.pinHashVersion = 2,
    this.hasCompletedSetup = false,
    this.previousPin,
    this.isPinReset = false,
  }) : super(
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
