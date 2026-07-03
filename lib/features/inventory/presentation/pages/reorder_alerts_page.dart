import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/domain/entities/product.dart';

class ReorderAlertsPage extends StatelessWidget {
  const ReorderAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reorder Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state.status == ProductStatus.loading && state.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final lowStock = state.products
              .where((p) => p.minStockLevel > 0 && p.stock <= p.minStockLevel)
              .toList()
            ..sort((a, b) => a.stock.compareTo(b.stock));

          if (lowStock.isEmpty) {
            return Column(
              children: [
                const Spacer(),
                Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                const SizedBox(height: 16),
                Text('All products are well-stocked!', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const Spacer(),
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${lowStock.length} product${lowStock.length == 1 ? '' : 's'} below reorder level',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange[900]),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Reorder needed',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600]))),
                      Expanded(flex: 2, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600]))),
                      Expanded(flex: 2, child: Text('Min', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600]))),
                      Expanded(flex: 2, child: Text('Short', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600]))),
                      Expanded(flex: 3, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600]))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Table rows
                Expanded(
                  child: ListView.separated(
                    itemCount: lowStock.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final product = lowStock[index];
                      return _buildRow(product);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/products'),
                    icon: const Icon(Icons.inventory, size: 18),
                    label: const Text('Manage Products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(Product product) {
    final shortage = product.minStockLevel - product.stock;

    UrgencyLevel urgency;
    if (product.stock <= 0) {
      urgency = UrgencyLevel.outOfStock;
    } else if (product.stock <= (product.minStockLevel ~/ 2)) {
      urgency = UrgencyLevel.critical;
    } else {
      urgency = UrgencyLevel.low;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: urgency.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: urgency.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: urgency.color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${product.stock}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: urgency.color),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${product.minStockLevel}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '+$shortage',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[400]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: urgency.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                urgency.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: urgency.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UrgencyLevel {
  final String label;
  final Color color;

  const UrgencyLevel._(this.label, this.color);

  static const outOfStock = UrgencyLevel._('OUT OF STOCK', Colors.red);
  static const critical = UrgencyLevel._('CRITICAL', Colors.deepOrange);
  static const low = UrgencyLevel._('LOW', Colors.orange);
}
