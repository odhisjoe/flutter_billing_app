import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/inventory_transaction.dart';

class InventoryMovementPage extends StatefulWidget {
  const InventoryMovementPage({super.key});

  @override
  State<InventoryMovementPage> createState() => _InventoryMovementPageState();
}

class _InventoryMovementPageState extends State<InventoryMovementPage> {
  String _typeFilter = 'all';
  String _searchQuery = '';

  List<InventoryTransaction> get _transactions {
    final all = HiveDatabase.inventoryBox.values
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return all.where((tx) {
      if (_typeFilter != 'all' && tx.type != _typeFilter) return false;
      if (_searchQuery.isNotEmpty && !tx.productName.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _transactions;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Inventory Movement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextFormField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by product name...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip('All', 'all'),
                _filterChip('Sale', 'sale'),
                _filterChip('Purchase', 'purchase_in'),
                _filterChip('Adjustment', 'adjustment'),
                _filterChip('Damaged', 'damaged'),
              ],
            ),
          ),
          if (transactions.isEmpty)
            Expanded(
              child: Center(
                child: Text('No transactions found', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionCard(tx);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        selected: isSelected,
        onSelected: (_) => setState(() => _typeFilter = value),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.primaryColor,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction tx) {
    final isIncoming = tx.quantity > 0;
    final isDamaged = tx.type == 'damaged';
    Color qtyColor;
    IconData icon;
    String typeLabel;

    switch (tx.type) {
      case 'sale':
        qtyColor = Colors.red;
        icon = Icons.shopping_cart;
        typeLabel = 'Sale';
      case 'purchase_in':
        qtyColor = Colors.green;
        icon = Icons.add_box;
        typeLabel = 'Purchase In';
      case 'adjustment':
        qtyColor = isIncoming ? Colors.blue : Colors.orange;
        icon = Icons.tune;
        typeLabel = 'Adjustment';
      case 'damaged':
        qtyColor = Colors.red;
        icon = Icons.warning_amber;
        typeLabel = 'Damaged';
      default:
        qtyColor = Colors.grey;
        icon = Icons.swap_horiz;
        typeLabel = tx.type;
    }

    final dateStr =
        '${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year} ${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: qtyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: qtyColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('$typeLabel • $dateStr',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (tx.reference != null && tx.reference!.isNotEmpty)
                    Text('Ref: ${tx.reference}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isIncoming ? '+${tx.quantity}' : '${tx.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDamaged ? Colors.red : qtyColor,
                  ),
                ),
                Text('${tx.stockBefore} → ${tx.stockAfter}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
