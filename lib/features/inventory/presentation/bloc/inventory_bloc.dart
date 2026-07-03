import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';
import '../../domain/usecases/inventory_usecases.dart';
import '../../domain/entities/inventory_transaction.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final AddTransactionUseCase addTransactionUseCase;
  final GetAllTransactionsUseCase getAllTransactionsUseCase;

  InventoryBloc({
    required this.addTransactionUseCase,
    required this.getAllTransactionsUseCase,
  }) : super(const InventoryState()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddAdjustment>(_onAddAdjustment);
    on<AddPurchaseIn>(_onAddPurchaseIn);
    on<AddDamaged>(_onAddDamaged);
  }

  void _onLoadTransactions(LoadTransactions event, Emitter<InventoryState> emit) {
    final txs = getAllTransactionsUseCase();
    emit(InventoryState(transactions: txs));
  }

  Future<void> _onAddAdjustment(AddAdjustment event, Emitter<InventoryState> emit) async {
    final tx = InventoryTransaction(
      id: const Uuid().v4(),
      productId: event.productId,
      productName: event.productName,
      type: TransactionType.adjustment,
      quantity: event.adjustmentQty,
      stockBefore: event.stockBefore,
      stockAfter: event.stockAfter,
      notes: event.notes,
      timestamp: DateTime.now(),
    );
    await addTransactionUseCase(tx);
    add(const LoadTransactions());
  }

  Future<void> _onAddPurchaseIn(AddPurchaseIn event, Emitter<InventoryState> emit) async {
    final tx = InventoryTransaction(
      id: const Uuid().v4(),
      productId: event.productId,
      productName: event.productName,
      type: TransactionType.purchaseIn,
      quantity: event.quantity,
      stockBefore: event.stockBefore,
      stockAfter: event.stockAfter,
      reference: event.reference,
      notes: event.notes,
      timestamp: DateTime.now(),
    );
    await addTransactionUseCase(tx);
    add(const LoadTransactions());
  }

  Future<void> _onAddDamaged(AddDamaged event, Emitter<InventoryState> emit) async {
    final tx = InventoryTransaction(
      id: const Uuid().v4(),
      productId: event.productId,
      productName: event.productName,
      type: TransactionType.damaged,
      quantity: -event.quantity,
      stockBefore: event.stockBefore,
      stockAfter: event.stockAfter,
      notes: event.notes,
      timestamp: DateTime.now(),
    );
    await addTransactionUseCase(tx);
    add(const LoadTransactions());
  }
}
