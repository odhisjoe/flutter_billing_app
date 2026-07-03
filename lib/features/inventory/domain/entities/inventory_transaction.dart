import 'package:equatable/equatable.dart';

class InventoryTransaction extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String type;
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final String? reference;
  final String? notes;
  final DateTime timestamp;
  final String? assignedTo;

  const InventoryTransaction({
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
  });

  InventoryTransaction copyWith({
    String? id,
    String? productId,
    String? productName,
    String? type,
    int? quantity,
    int? stockBefore,
    int? stockAfter,
    String? reference,
    String? notes,
    DateTime? timestamp,
    String? assignedTo,
    bool clearAssignedTo = false,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      stockBefore: stockBefore ?? this.stockBefore,
      stockAfter: stockAfter ?? this.stockAfter,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, productName, type, quantity, stockBefore, stockAfter, reference, notes, timestamp, assignedTo];
}

class TransactionType {
  static const String sale = 'sale';
  static const String purchaseIn = 'purchase_in';
  static const String adjustment = 'adjustment';
  static const String damaged = 'damaged';
  static const String stockOut = 'stock_out';

  static const List<String> values = [sale, purchaseIn, adjustment, damaged, stockOut];

  static String label(String type) {
    switch (type) {
      case sale:
        return 'Sale';
      case purchaseIn:
        return 'Purchase In';
      case adjustment:
        return 'Adjustment';
      case damaged:
        return 'Damaged';
      case stockOut:
        return 'Stock Out';
      default:
        return type;
    }
  }
}
