// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryTransactionModelAdapter
    extends TypeAdapter<InventoryTransactionModel> {
  @override
  final int typeId = 4;

  @override
  InventoryTransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryTransactionModel(
      id: fields[0] as String,
      productId: fields[1] as String,
      productName: fields[2] as String,
      type: fields[3] as String,
      quantity: fields[4] as int,
      stockBefore: fields[5] as int,
      stockAfter: fields[6] as int,
      reference: fields[7] as String?,
      notes: fields[8] as String?,
      timestamp: fields[9] as DateTime,
      assignedTo: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryTransactionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.stockBefore)
      ..writeByte(6)
      ..write(obj.stockAfter)
      ..writeByte(7)
      ..write(obj.reference)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.timestamp)
      ..writeByte(10)
      ..write(obj.assignedTo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryTransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
