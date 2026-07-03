import '../../../../core/data/hive_database.dart';
import '../../domain/entities/inventory_transaction.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_transaction_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  @override
  Future<void> addTransaction(InventoryTransaction transaction) async {
    final model = InventoryTransactionModel.fromEntity(transaction);
    await HiveDatabase.inventoryBox.put(model.id, model);
  }

  @override
  List<InventoryTransaction> getAllTransactions() {
    return HiveDatabase.inventoryBox.values
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  List<InventoryTransaction> getTransactionsByProduct(String productId) {
    return HiveDatabase.inventoryBox.values
        .where((m) => m.productId == productId)
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  List<InventoryTransaction> getTransactionsByType(String type) {
    return HiveDatabase.inventoryBox.values
        .where((m) => m.type == type)
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
