import 'package:hive/hive.dart';
import '../../domain/entities/inventory_transaction.dart';

part 'inventory_transaction_model.g.dart';

@HiveType(typeId: 4)
class InventoryTransactionModel extends InventoryTransaction {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String productId;
  @override
  @HiveField(2)
  final String productName;
  @override
  @HiveField(3)
  final String type;
  @override
  @HiveField(4)
  final int quantity;
  @override
  @HiveField(5)
  final int stockBefore;
  @override
  @HiveField(6)
  final int stockAfter;
  @override
  @HiveField(7)
  final String? reference;
  @override
  @HiveField(8)
  final String? notes;
  @override
  @HiveField(9)
  final DateTime timestamp;
  @override
  @HiveField(10)
  final String? assignedTo;

  const InventoryTransactionModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.reference,
    this.notes,
    required this.timestamp,
    this.assignedTo,
  }) : super(
          id: id,
          productId: productId,
          productName: productName,
          type: type,
          quantity: quantity,
          stockBefore: stockBefore,
          stockAfter: stockAfter,
          reference: reference,
          notes: notes,
          timestamp: timestamp,
          assignedTo: assignedTo,
        );

  factory InventoryTransactionModel.fromEntity(InventoryTransaction tx) {
    return InventoryTransactionModel(
      id: tx.id,
      productId: tx.productId,
      productName: tx.productName,
      type: tx.type,
      quantity: tx.quantity,
      stockBefore: tx.stockBefore,
      stockAfter: tx.stockAfter,
      reference: tx.reference,
      notes: tx.notes,
      timestamp: tx.timestamp,
      assignedTo: tx.assignedTo,
    );
  }

  InventoryTransaction toEntity() {
    return InventoryTransaction(
      id: id,
      productId: productId,
      productName: productName,
      type: type,
      quantity: quantity,
      stockBefore: stockBefore,
      stockAfter: stockAfter,
      reference: reference,
      notes: notes,
      timestamp: timestamp,
      assignedTo: assignedTo,
    );
  }
}
