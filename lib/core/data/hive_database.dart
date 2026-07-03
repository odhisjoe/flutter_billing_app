import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/reports/data/models/sale_model.dart';
import '../../features/inventory/data/models/inventory_transaction_model.dart';
import '../../features/customer/data/models/customer_model.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/supplier/data/models/supplier_model.dart';

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 8;

  @override
  UserRole read(BinaryReader reader) => UserRole.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, UserRole obj) =>
      writer.writeByte(obj.index);
}

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String salesBoxName = 'sales';
  static const String inventoryBoxName = 'inventory';
  static const String customerBoxName = 'customers';
  static const String schemaVersionKey = 'schema_version';
  static const String supplierBoxName = 'suppliers';
  static const String userBoxName = 'users';
  static const int appSchemaVersion = 8;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(SaleModelAdapter());
    Hive.registerAdapter(SaleItemModelAdapter());
    Hive.registerAdapter(InventoryTransactionModelAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(SupplierModelAdapter());
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(UserRoleAdapter());

    // Open settings first (no typed adapter needed for schema check)
    await Hive.openBox(settingsBoxName);

    // Migration: check schema version and delete stale boxes BEFORE
    // opening typed boxes, so incompatible old data doesn't crash the adapter.
    final settings = Hive.box(settingsBoxName);
    final storedVersion = settings.get(schemaVersionKey, defaultValue: 1) as int;
    if (storedVersion != appSchemaVersion) {
      // Delete boxes whose schema may have changed (e.g. UserRole enum added)
      for (final name in [productBoxName, userBoxName, inventoryBoxName]) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (_) {
          // Box may not exist on disk yet
        }
      }
      await settings.put(schemaVersionKey, appSchemaVersion);
    }

    // Open typed boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox<SaleModel>(salesBoxName);
    await Hive.openBox<InventoryTransactionModel>(inventoryBoxName);
    await Hive.openBox<CustomerModel>(customerBoxName);
    await Hive.openBox<SupplierModel>(supplierBoxName);

    // Open users box with a safety net – old Hive data may have UserRole
    // stored as a raw int (before UserRoleAdapter was registered).
    try {
      await Hive.openBox<UserModel>(userBoxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(userBoxName);
      await Hive.openBox<UserModel>(userBoxName);
    }
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<SaleModel> get salesBox => Hive.box<SaleModel>(salesBoxName);
  static Box<InventoryTransactionModel> get inventoryBox =>
      Hive.box<InventoryTransactionModel>(inventoryBoxName);
  static Box<CustomerModel> get customerBox =>
      Hive.box<CustomerModel>(customerBoxName);
  static Box<SupplierModel> get supplierBox =>
      Hive.box<SupplierModel>(supplierBoxName);
  static Box<UserModel> get usersBox =>
      Hive.box<UserModel>(userBoxName);
}
