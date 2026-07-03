import '../entities/inventory_transaction.dart';
import '../repositories/inventory_repository.dart';

class AddTransactionUseCase {
  final InventoryRepository repository;
  AddTransactionUseCase(this.repository);

  Future<void> call(InventoryTransaction transaction) =>
      repository.addTransaction(transaction);
}

class GetAllTransactionsUseCase {
  final InventoryRepository repository;
  GetAllTransactionsUseCase(this.repository);

  List<InventoryTransaction> call() => repository.getAllTransactions();
}

class GetTransactionsByProductUseCase {
  final InventoryRepository repository;
  GetTransactionsByProductUseCase(this.repository);

  List<InventoryTransaction> call(String productId) =>
      repository.getTransactionsByProduct(productId);
}

class GetTransactionsByTypeUseCase {
  final InventoryRepository repository;
  GetTransactionsByTypeUseCase(this.repository);

  List<InventoryTransaction> call(String type) =>
      repository.getTransactionsByType(type);
}
