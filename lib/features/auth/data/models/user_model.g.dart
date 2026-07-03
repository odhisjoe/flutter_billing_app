// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 7;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      name: fields[1] as String,
      pin: fields[2] as String,
      role: fields[3] as UserRole,
      isActive: fields[4] as bool,
      pinHashVersion: fields[5] as int,
      hasCompletedSetup: fields[6] as bool? ?? false,
      previousPin: fields[7] as String?,
      isPinReset: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.pin)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.pinHashVersion)
      ..writeByte(6)
      ..write(obj.hasCompletedSetup)
      ..writeByte(7)
      ..write(obj.previousPin)
      ..writeByte(8)
      ..write(obj.isPinReset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
