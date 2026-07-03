import 'package:billing_app/features/auth/data/models/user_model.dart';
import 'package:billing_app/features/auth/domain/entities/user.dart';
import 'package:billing_app/features/customer/data/models/customer_model.dart';
import 'package:billing_app/features/inventory/data/models/inventory_transaction_model.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/reports/data/models/sale_model.dart';
import 'package:billing_app/features/shop/data/models/shop_model.dart';
import 'package:billing_app/features/supplier/data/models/supplier_model.dart';

class SyncSerializer {
  static Map<String, dynamic>? modelToMap(String collection, dynamic model) {
    switch (collection) {
      case 'products':
        return _productToMap(model as ProductModel);
      case 'shop':
        return _shopToMap(model as ShopModel);
      case 'sales':
        return _saleToMap(model as SaleModel);
      case 'inventory':
        return _inventoryTxToMap(model as InventoryTransactionModel);
      case 'customers':
        return _customerToMap(model as CustomerModel);
      case 'suppliers':
        return _supplierToMap(model as SupplierModel);
      case 'users':
        return _userToMap(model as UserModel);
      default:
        return null;
    }
  }

  static dynamic mapToModel(String collection, Map<String, dynamic> data) {
    switch (collection) {
      case 'products':
        return _productFromMap(data);
      case 'shop':
        return _shopFromMap(data);
      case 'sales':
        return _saleFromMap(data);
      case 'inventory':
        return _inventoryTxFromMap(data);
      case 'customers':
        return _customerFromMap(data);
      case 'suppliers':
        return _supplierFromMap(data);
      case 'users':
        return _userFromMap(data);
      default:
        return null;
    }
  }

  static Map<String, dynamic> _productToMap(ProductModel p) => {
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

  static ProductModel _productFromMap(Map<String, dynamic> m) => ProductModel(
        id: m['id'] as String,
        name: m['name'] as String,
        barcode: m['barcode'] as String,
        price: (m['price'] as num).toDouble(),
        stock: (m['stock'] as num).toInt(),
        category: m['category'] as String?,
        imageUrl: m['imageUrl'] as String?,
        sku: m['sku'] as String?,
        buyingPrice: (m['buyingPrice'] as num?)?.toDouble() ?? 0,
        supplier: m['supplier'] as String?,
        minStockLevel: (m['minStockLevel'] as num?)?.toInt() ?? 0,
        assignedTo: m['assignedTo'] as String?,
      );

  static Map<String, dynamic> _shopToMap(ShopModel s) => {
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

  static ShopModel _shopFromMap(Map<String, dynamic> m) => ShopModel(
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

  static Map<String, dynamic> _saleItemToMap(SaleItemModel i) => {
        'productId': i.productId,
        'productName': i.productName,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
        'buyingPrice': i.buyingPrice,
        'total': i.total,
      };

  static SaleItemModel _saleItemFromMap(Map<String, dynamic> m) => SaleItemModel(
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        quantity: (m['quantity'] as num).toInt(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        buyingPrice: (m['buyingPrice'] as num?)?.toDouble() ?? 0,
        total: (m['total'] as num).toDouble(),
      );

  static Map<String, dynamic> _saleToMap(SaleModel s) => {
        'id': s.id,
        'date': s.date.toUtc().toIso8601String(),
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

  static SaleModel _saleFromMap(Map<String, dynamic> m) {
    final items = (m['items'] as List<dynamic>?)
            ?.map((i) => _saleItemFromMap(i as Map<String, dynamic>))
            .toList() ??
        [];

    final date = DateTime.tryParse(m['date'] as String? ?? '')?.toLocal();

    return SaleModel(
      id: m['id'] as String,
      date: date ?? DateTime.now(),
      items: items,
      subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
      vatRate: (m['vatRate'] as num?)?.toDouble() ?? 0,
      vatAmount: (m['vatAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (m['grandTotal'] as num?)?.toDouble() ?? 0,
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
  }

  static Map<String, dynamic> _inventoryTxToMap(InventoryTransactionModel tx) => {
        'id': tx.id,
        'productId': tx.productId,
        'productName': tx.productName,
        'type': tx.type,
        'quantity': tx.quantity,
        'stockBefore': tx.stockBefore,
        'stockAfter': tx.stockAfter,
        'reference': tx.reference,
        'notes': tx.notes,
        'timestamp': tx.timestamp.toUtc().toIso8601String(),
      };

  static InventoryTransactionModel _inventoryTxFromMap(Map<String, dynamic> m) {
    final ts = DateTime.tryParse(m['timestamp'] as String? ?? '')?.toLocal();

    return InventoryTransactionModel(
      id: m['id'] as String,
      productId: m['productId'] as String,
      productName: m['productName'] as String,
      type: m['type'] as String,
      quantity: (m['quantity'] as num).toInt(),
      stockBefore: (m['stockBefore'] as num?)?.toInt() ?? 0,
      stockAfter: (m['stockAfter'] as num?)?.toInt() ?? 0,
      reference: m['reference'] as String?,
      notes: m['notes'] as String?,
      timestamp: ts ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> _customerToMap(CustomerModel c) => {
        'id': c.id,
        'name': c.name,
        'phoneNumber': c.phoneNumber,
        'email': c.email,
        'address': c.address,
        'loyaltyPoints': c.loyaltyPoints,
        'totalSpent': c.totalSpent,
        'createdAt': c.createdAt.toUtc().toIso8601String(),
      };

  static CustomerModel _customerFromMap(Map<String, dynamic> m) {
    final createdAt = DateTime.tryParse(m['createdAt'] as String? ?? '');
    return CustomerModel(
      id: m['id'] as String,
      name: m['name'] as String,
      phoneNumber: m['phoneNumber'] as String,
      email: m['email'] as String?,
      address: m['address'] as String?,
      loyaltyPoints: (m['loyaltyPoints'] as num?)?.toInt() ?? 0,
      totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> _supplierToMap(SupplierModel s) => {
        'id': s.id,
        'name': s.name,
        'phoneNumber': s.phoneNumber,
        'email': s.email,
        'address': s.address,
        'createdAt': s.createdAt.toUtc().toIso8601String(),
      };

  static SupplierModel _supplierFromMap(Map<String, dynamic> m) {
    final createdAt = DateTime.tryParse(m['createdAt'] as String? ?? '');
    return SupplierModel(
      id: m['id'] as String,
      name: m['name'] as String,
      phoneNumber: m['phoneNumber'] as String,
      email: m['email'] as String?,
      address: m['address'] as String?,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> _userToMap(UserModel u) => {
        'id': u.id,
        'name': u.name,
        'pin': u.pin,
        'role': u.role.name,
        'isActive': u.isActive,
      };

  static UserModel _userFromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'] as String,
        name: m['name'] as String,
        pin: m['pin'] as String,
        role: UserRole.values.firstWhere((r) => r.name == m['role']),
        isActive: m['isActive'] as bool? ?? true,
      );
}
