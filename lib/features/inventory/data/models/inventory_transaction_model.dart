import 'package:hive/hive.dart';
import '../../domain/entities/inventory_transaction.dart';

part 'inventory_transaction_model.g.dart';

@HiveType(typeId: 4)
class InventoryTransactionModel extends InventoryTransaction {
  const InventoryTransactionModel({
    required super.id,
    required super.productId,
    required super.productName,
    required super.type,
    required super.quantity,
    required super.stockBefore,
    required super.stockAfter,
    super.reference,
    super.notes,
    required super.timestamp,
    super.assignedTo,
  });

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
