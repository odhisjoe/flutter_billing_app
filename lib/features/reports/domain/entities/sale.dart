import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double buyingPrice;
  final double total;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.buyingPrice = 0,
    required this.total,
  });

  @override
  List<Object?> get props =>
      [productId, productName, quantity, unitPrice, buyingPrice, total];
}

class Sale extends Equatable {
  final String id;
  final DateTime date;
  final List<SaleItem> items;
  final double subtotal;
  final double vatRate;
  final double vatAmount;
  final double grandTotal;
  final double cash;
  final double mpesa;
  final double card;
  final double bank;
  final double change;
  final String shopName;
  final String? customerId;
  final String? customerName;
  final String? cashierId;
  final String? cashierName;

  const Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.vatRate,
    required this.vatAmount,
    required this.grandTotal,
    this.cash = 0,
    this.mpesa = 0,
    this.card = 0,
    this.bank = 0,
    this.change = 0,
    this.shopName = '',
    this.customerId,
    this.customerName,
    this.cashierId,
    this.cashierName,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        items,
        subtotal,
        vatRate,
        vatAmount,
        grandTotal,
        cash,
        mpesa,
        card,
        bank,
        change,
        shopName,
        customerId,
        customerName,
        cashierId,
        cashierName,
      ];
}
