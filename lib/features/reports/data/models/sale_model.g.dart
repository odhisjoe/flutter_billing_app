// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleModelAdapter extends TypeAdapter<SaleModel> {
  @override
  final int typeId = 2;

  @override
  SaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      items: (fields[2] as List).cast<SaleItemModel>(),
      subtotal: fields[3] as double,
      vatRate: fields[4] as double,
      vatAmount: fields[5] as double,
      grandTotal: fields[6] as double,
      cash: fields[7] as double,
      mpesa: fields[8] as double,
      card: fields[9] as double,
      bank: fields[10] as double,
      change: fields[11] as double,
      shopName: fields[12] as String,
      customerId: fields[13] as String?,
      customerName: fields[14] as String?,
      cashierId: fields[15] as String?,
      cashierName: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.subtotal)
      ..writeByte(4)
      ..write(obj.vatRate)
      ..writeByte(5)
      ..write(obj.vatAmount)
      ..writeByte(6)
      ..write(obj.grandTotal)
      ..writeByte(7)
      ..write(obj.cash)
      ..writeByte(8)
      ..write(obj.mpesa)
      ..writeByte(9)
      ..write(obj.card)
      ..writeByte(10)
      ..write(obj.bank)
      ..writeByte(11)
      ..write(obj.change)
      ..writeByte(12)
      ..write(obj.shopName)
      ..writeByte(13)
      ..write(obj.customerId)
      ..writeByte(14)
      ..write(obj.customerName)
      ..writeByte(15)
      ..write(obj.cashierId)
      ..writeByte(16)
      ..write(obj.cashierName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleItemModelAdapter extends TypeAdapter<SaleItemModel> {
  @override
  final int typeId = 3;

  @override
  SaleItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItemModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as int,
      unitPrice: fields[3] as double,
      buyingPrice: fields[4] as double,
      total: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SaleItemModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.buyingPrice)
      ..writeByte(5)
      ..write(obj.total);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
