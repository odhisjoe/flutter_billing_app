import 'package:equatable/equatable.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends InventoryEvent {
  const LoadTransactions();
}

class AddAdjustment extends InventoryEvent {
  final String productId;
  final String productName;
  final int adjustmentQty;
  final String? notes;
  final int stockBefore;
  final int stockAfter;

  const AddAdjustment({
    required this.productId,
    required this.productName,
    required this.adjustmentQty,
    this.notes,
    required this.stockBefore,
    required this.stockAfter,
  });

  @override
  List<Object?> get props => [productId, productName, adjustmentQty, notes, stockBefore, stockAfter];
}

class AddPurchaseIn extends InventoryEvent {
  final String productId;
  final String productName;
  final int quantity;
  final String? reference;
  final String? notes;
  final int stockBefore;
  final int stockAfter;

  const AddPurchaseIn({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.reference,
    this.notes,
    required this.stockBefore,
    required this.stockAfter,
  });

  @override
  List<Object?> get props => [productId, productName, quantity, reference, notes, stockBefore, stockAfter];
}

class AddDamaged extends InventoryEvent {
  final String productId;
  final String productName;
  final int quantity;
  final String? notes;
  final int stockBefore;
  final int stockAfter;

  const AddDamaged({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.notes,
    required this.stockBefore,
    required this.stockAfter,
  });

  @override
  List<Object?> get props => [productId, productName, quantity, notes, stockBefore, stockAfter];
}
