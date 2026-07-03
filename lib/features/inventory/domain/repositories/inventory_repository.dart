import '../entities/inventory_transaction.dart';

abstract class InventoryRepository {
  Future<void> addTransaction(InventoryTransaction transaction);
  List<InventoryTransaction> getAllTransactions();
  List<InventoryTransaction> getTransactionsByProduct(String productId);
  List<InventoryTransaction> getTransactionsByType(String type);
}
