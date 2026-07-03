import 'package:equatable/equatable.dart';

enum UserRole { admin, cashier, superAdmin }

class User extends Equatable {
  final String id;
  final String name;
  final String pin;
  final UserRole role;
  final bool isActive;
  final int pinHashVersion;
  final bool hasCompletedSetup;
  final String? previousPin;
  final bool isPinReset;

  const User({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.isActive = true,
    this.pinHashVersion = 2,
    this.hasCompletedSetup = false,
    this.previousPin,
    this.isPinReset = false,
  });

  bool get isSuperAdmin => role == UserRole.superAdmin;

  User copyWith({
    String? id,
    String? name,
    String? pin,
    UserRole? role,
    bool? isActive,
    int? pinHashVersion,
    bool? hasCompletedSetup,
    String? previousPin,
    bool clearPreviousPin = false,
    bool? isPinReset,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      pinHashVersion: pinHashVersion ?? this.pinHashVersion,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
      previousPin: clearPreviousPin ? null : (previousPin ?? this.previousPin),
      isPinReset: isPinReset ?? this.isPinReset,
    );
  }

  @override
  List<Object?> get props => [id, name, pin, role, isActive, pinHashVersion, hasCompletedSetup, previousPin, isPinReset];
}
