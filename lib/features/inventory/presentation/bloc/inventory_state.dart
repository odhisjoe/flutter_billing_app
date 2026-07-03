import 'package:equatable/equatable.dart';
import '../../domain/entities/inventory_transaction.dart';

class InventoryState extends Equatable {
  final List<InventoryTransaction> transactions;
  final bool isLoading;

  const InventoryState({
    this.transactions = const [],
    this.isLoading = false,
  });

  InventoryState copyWith({
    List<InventoryTransaction>? transactions,
    bool? isLoading,
  }) {
    return InventoryState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [transactions, isLoading];
}
