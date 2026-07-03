import 'package:hive/hive.dart';
import '../../domain/entities/sale.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 2)
class SaleModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final List<SaleItemModel> items;
  @HiveField(3)
  final double subtotal;
  @HiveField(4)
  final double vatRate;
  @HiveField(5)
  final double vatAmount;
  @HiveField(6)
  final double grandTotal;
  @HiveField(7)
  final double cash;
  @HiveField(8)
  final double mpesa;
  @HiveField(9)
  final double card;
  @HiveField(10)
  final double bank;
  @HiveField(11)
  final double change;
  @HiveField(12)
  final String shopName;
  @HiveField(13)
  final String? customerId;
  @HiveField(14)
  final String? customerName;
  @HiveField(15)
  final String? cashierId;
  @HiveField(16)
  final String? cashierName;

  const SaleModel({
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

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      date: sale.date,
      items: sale.items.map((e) => SaleItemModel.fromEntity(e)).toList(),
      subtotal: sale.subtotal,
      vatRate: sale.vatRate,
      vatAmount: sale.vatAmount,
      grandTotal: sale.grandTotal,
      cash: sale.cash,
      mpesa: sale.mpesa,
      card: sale.card,
      bank: sale.bank,
      change: sale.change,
      shopName: sale.shopName,
      customerId: sale.customerId,
      customerName: sale.customerName,
      cashierId: sale.cashierId,
      cashierName: sale.cashierName,
    );
  }

  Sale toEntity() {
    return Sale(
      id: id,
      date: date,
      items: items.map((e) => e.toEntity()).toList(),
      subtotal: subtotal,
      vatRate: vatRate,
      vatAmount: vatAmount,
      grandTotal: grandTotal,
      cash: cash,
      mpesa: mpesa,
      card: card,
      bank: bank,
      change: change,
      shopName: shopName,
      customerId: customerId,
      customerName: customerName,
      cashierId: cashierId,
      cashierName: cashierName,
    );
  }
}

@HiveType(typeId: 3)
class SaleItemModel {
  @HiveField(0)
  final String productId;
  @HiveField(1)
  final String productName;
  @HiveField(2)
  final int quantity;
  @HiveField(3)
  final double unitPrice;
  @HiveField(4)
  final double buyingPrice;
  @HiveField(5)
  final double total;

  const SaleItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.buyingPrice = 0,
    required this.total,
  });

  factory SaleItemModel.fromEntity(SaleItem item) {
    return SaleItemModel(
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      buyingPrice: item.buyingPrice,
      total: item.total,
    );
  }

  SaleItem toEntity() {
    return SaleItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      buyingPrice: buyingPrice,
      total: total,
    );
  }
}
