import 'dart:convert';

import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/features/auth/data/models/user_model.dart';
import 'package:billing_app/features/auth/domain/entities/user.dart';
import 'package:billing_app/features/customer/data/models/customer_model.dart';
import 'package:billing_app/features/customer/domain/entities/customer.dart';
import 'package:billing_app/features/inventory/data/models/inventory_transaction_model.dart';
import 'package:billing_app/features/inventory/domain/entities/inventory_transaction.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/reports/data/models/sale_model.dart';
import 'package:billing_app/features/reports/domain/entities/sale.dart';
import 'package:billing_app/features/shop/data/models/shop_model.dart';
import 'package:billing_app/features/shop/domain/entities/shop.dart';
import 'package:billing_app/features/supplier/data/models/supplier_model.dart';
import 'package:billing_app/features/supplier/domain/entities/supplier.dart';
import 'package:hive/hive.dart';

class BackupService {
  static const _version = 1;

  static String exportToJson() {
    final data = <String, dynamic>{};

    data['products'] = _exportBox<ProductModel>(HiveDatabase.productBox,
        (e) => _productToMap(e.toEntity()));
    data['shop'] = _exportBox<ShopModel>(HiveDatabase.shopBox,
        (e) => _shopToMap(e.toEntity()));
    data['sales'] = _exportBox<SaleModel>(HiveDatabase.salesBox,
        (e) => _saleToMap(e.toEntity()));
    data['inventory'] = _exportBox<InventoryTransactionModel>(
        HiveDatabase.inventoryBox,
        (e) => _inventoryTxToMap(e.toEntity()));
    data['customers'] = _exportBox<CustomerModel>(HiveDatabase.customerBox,
        (e) => _customerToMap(e.toEntity()));
    data['suppliers'] = _exportBox<SupplierModel>(HiveDatabase.supplierBox,
        (e) => _supplierToMap(e.toEntity()));
    data['users'] = _exportBox<UserModel>(HiveDatabase.usersBox,
        (e) => _userToMap(e.toEntity()));
    data['settings'] = _exportSettings();

    return const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });
  }

  static Future<void> importFromJson(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;

    final productBox = HiveDatabase.productBox;
    final shopBox = HiveDatabase.shopBox;
    final salesBox = HiveDatabase.salesBox;
    final inventoryBox = HiveDatabase.inventoryBox;
    final customerBox = HiveDatabase.customerBox;
    final supplierBox = HiveDatabase.supplierBox;
    final usersBox = HiveDatabase.usersBox;
    final settingsBox = HiveDatabase.settingsBox;

    if (data.containsKey('products')) {
      await productBox.clear();
      for (final map in data['products'] as List<dynamic>) {
        final product = _productFromMap(map as Map<String, dynamic>);
        await productBox.put(product.id, ProductModel.fromEntity(product));
      }
    }

    if (data.containsKey('shop') && (data['shop'] as List).isNotEmpty) {
      await shopBox.clear();
      final map = (data['shop'] as List).first as Map<String, dynamic>;
      final shop = _shopFromMap(map);
      await shopBox.put('default', ShopModel.fromEntity(shop));
    }

    if (data.containsKey('sales')) {
      await salesBox.clear();
      for (final map in data['sales'] as List<dynamic>) {
        final sale = _saleFromMap(map as Map<String, dynamic>);
        await salesBox.put(sale.id, SaleModel.fromEntity(sale));
      }
    }

    if (data.containsKey('inventory')) {
      await inventoryBox.clear();
      for (final map in data['inventory'] as List<dynamic>) {
        final tx = _inventoryTxFromMap(map as Map<String, dynamic>);
        await inventoryBox.put(tx.id, InventoryTransactionModel.fromEntity(tx));
      }
    }

    if (data.containsKey('customers')) {
      await customerBox.clear();
      for (final map in data['customers'] as List<dynamic>) {
        final customer = _customerFromMap(map as Map<String, dynamic>);
        await customerBox.put(customer.id, CustomerModel.fromEntity(customer));
      }
    }

    if (data.containsKey('suppliers')) {
      await supplierBox.clear();
      for (final map in data['suppliers'] as List<dynamic>) {
        final supplier = _supplierFromMap(map as Map<String, dynamic>);
        await supplierBox.put(supplier.id, SupplierModel.fromEntity(supplier));
      }
    }

    if (data.containsKey('users')) {
      await usersBox.clear();
      for (final map in data['users'] as List<dynamic>) {
        final user = _userFromMap(map as Map<String, dynamic>);
        await usersBox.put(user.id, UserModel.fromEntity(user));
      }
    }

    if (data.containsKey('settings')) {
      for (final entry in data['settings'] as List<dynamic>) {
        final e = entry as Map<String, dynamic>;
        await settingsBox.put(e['k'] as String, e['v']);
      }
    }
  }

  static List<Map<String, dynamic>> _exportBox<T>(
      Box<T> box, Map<String, dynamic> Function(T) toMap) {
    return box.values.map((e) => toMap(e)).toList();
  }

  static List<Map<String, dynamic>> _exportSettings() {
    final box = HiveDatabase.settingsBox;
    return box.toMap().entries.map((e) {
      return {'k': e.key, 'v': e.value};
    }).toList();
  }

  static Map<String, dynamic> _productToMap(Product p) => {
        'id': p.id,
        'name': p.name,
        'barcode': p.barcode,
        'price': p.price,
        'stock': p.stock,
        'category': p.category,
        'imageUrl': p.imageUrl,
        'sku': p.sku,
        'buyingPrice': p.buyingPrice,
        'supplier': p.supplier,
        'minStockLevel': p.minStockLevel,
        'assignedTo': p.assignedTo,
      };

  static Product _productFromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String,
        barcode: m['barcode'] as String,
        price: (m['price'] as num).toDouble(),
        stock: (m['stock'] as num).toInt(),
        category: m['category'] as String?,
        imageUrl: m['imageUrl'] as String?,
        sku: m['sku'] as String?,
        buyingPrice: (m['buyingPrice'] as num).toDouble(),
        supplier: m['supplier'] as String?,
        minStockLevel: (m['minStockLevel'] as num).toInt(),
        assignedTo: m['assignedTo'] as String?,
      );

  static Map<String, dynamic> _shopToMap(Shop s) => {
        'name': s.name,
        'addressLine1': s.addressLine1,
        'addressLine2': s.addressLine2,
        'phoneNumber': s.phoneNumber,
        'mpesaTillNumber': s.mpesaTillNumber,
        'footerText': s.footerText,
        'vatRate': s.vatRate,
        'kraPin': s.kraPin,
        'logoUrl': s.logoUrl,
        'loyaltyPointsPerCurrency': s.loyaltyPointsPerCurrency,
        'currencyPerPoint': s.currencyPerPoint,
      };

  static Shop _shopFromMap(Map<String, dynamic> m) => Shop(
        name: m['name'] as String? ?? '',
        addressLine1: m['addressLine1'] as String? ?? '',
        addressLine2: m['addressLine2'] as String? ?? '',
        phoneNumber: m['phoneNumber'] as String? ?? '',
        mpesaTillNumber: m['mpesaTillNumber'] as String? ?? '',
        footerText: m['footerText'] as String? ?? '',
        vatRate: (m['vatRate'] as num?)?.toDouble() ?? 0,
        kraPin: m['kraPin'] as String? ?? '',
        logoUrl: m['logoUrl'] as String?,
        loyaltyPointsPerCurrency: (m['loyaltyPointsPerCurrency'] as num?)?.toInt() ?? 10,
        currencyPerPoint: (m['currencyPerPoint'] as num?)?.toInt() ?? 100,
      );

  static Map<String, dynamic> _saleItemToMap(SaleItem i) => {
        'productId': i.productId,
        'productName': i.productName,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
        'buyingPrice': i.buyingPrice,
        'total': i.total,
      };

  static SaleItem _saleItemFromMap(Map<String, dynamic> m) => SaleItem(
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        quantity: (m['quantity'] as num).toInt(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        buyingPrice: (m['buyingPrice'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num).toDouble(),
      );

  static Map<String, dynamic> _saleToMap(Sale s) => {
        'id': s.id,
        'date': s.date.toIso8601String(),
        'items': s.items.map(_saleItemToMap).toList(),
        'subtotal': s.subtotal,
        'vatRate': s.vatRate,
        'vatAmount': s.vatAmount,
        'grandTotal': s.grandTotal,
        'cash': s.cash,
        'mpesa': s.mpesa,
        'card': s.card,
        'bank': s.bank,
        'change': s.change,
        'shopName': s.shopName,
        'customerId': s.customerId,
        'customerName': s.customerName,
        'cashierId': s.cashierId,
        'cashierName': s.cashierName,
      };

  static Sale _saleFromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        items: (m['items'] as List<dynamic>)
            .map((i) => _saleItemFromMap(i as Map<String, dynamic>))
            .toList(),
        subtotal: (m['subtotal'] as num).toDouble(),
        vatRate: (m['vatRate'] as num).toDouble(),
        vatAmount: (m['vatAmount'] as num).toDouble(),
        grandTotal: (m['grandTotal'] as num).toDouble(),
        cash: (m['cash'] as num?)?.toDouble() ?? 0,
        mpesa: (m['mpesa'] as num?)?.toDouble() ?? 0,
        card: (m['card'] as num?)?.toDouble() ?? 0,
        bank: (m['bank'] as num?)?.toDouble() ?? 0,
        change: (m['change'] as num?)?.toDouble() ?? 0,
        shopName: m['shopName'] as String? ?? '',
        customerId: m['customerId'] as String?,
        customerName: m['customerName'] as String?,
        cashierId: m['cashierId'] as String?,
        cashierName: m['cashierName'] as String?,
      );

  static Map<String, dynamic> _inventoryTxToMap(InventoryTransaction tx) => {
        'id': tx.id,
        'productId': tx.productId,
        'productName': tx.productName,
        'type': tx.type,
        'quantity': tx.quantity,
        'stockBefore': tx.stockBefore,
        'stockAfter': tx.stockAfter,
        'reference': tx.reference,
        'notes': tx.notes,
        'timestamp': tx.timestamp.toIso8601String(),
      };

  static InventoryTransaction _inventoryTxFromMap(Map<String, dynamic> m) =>
      InventoryTransaction(
        id: m['id'] as String,
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        type: m['type'] as String,
        quantity: (m['quantity'] as num).toInt(),
        stockBefore: (m['stockBefore'] as num).toInt(),
        stockAfter: (m['stockAfter'] as num).toInt(),
        reference: m['reference'] as String?,
        notes: m['notes'] as String?,
        timestamp: DateTime.parse(m['timestamp'] as String),
      );

  static Map<String, dynamic> _customerToMap(Customer c) => {
        'id': c.id,
        'name': c.name,
        'phoneNumber': c.phoneNumber,
        'email': c.email,
        'address': c.address,
        'loyaltyPoints': c.loyaltyPoints,
        'totalSpent': c.totalSpent,
        'createdAt': c.createdAt.toIso8601String(),
      };

  static Customer _customerFromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phoneNumber: m['phoneNumber'] as String,
        email: m['email'] as String?,
        address: m['address'] as String?,
        loyaltyPoints: (m['loyaltyPoints'] as num?)?.toInt() ?? 0,
        totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  static Map<String, dynamic> _supplierToMap(Supplier s) => {
        'id': s.id,
        'name': s.name,
        'phoneNumber': s.phoneNumber,
        'email': s.email,
        'address': s.address,
        'createdAt': s.createdAt.toIso8601String(),
      };

  static Supplier _supplierFromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as String,
        name: m['name'] as String,
        phoneNumber: m['phoneNumber'] as String,
        email: m['email'] as String?,
        address: m['address'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  static Map<String, dynamic> _userToMap(User u) => {
        'id': u.id,
        'name': u.name,
        'pin': u.pin,
        'role': u.role.name,
        'isActive': u.isActive,
      };

  static User _userFromMap(Map<String, dynamic> m) => User(
        id: m['id'] as String,
        name: m['name'] as String,
        pin: m['pin'] as String,
        role: UserRole.values.firstWhere((r) => r.name == m['role']),
        isActive: m['isActive'] as bool? ?? true,
      );
}
