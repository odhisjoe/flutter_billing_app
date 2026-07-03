import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';
import '../../../reports/data/models/sale_model.dart';

class CustomerDetailPage extends StatelessWidget {
  final String customerId;
  const CustomerDetailPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        final customer = state.customers.where((c) => c.id == customerId).firstOrNull;
        if (customer == null) {
          return Scaffold(
            appBar: _appBar(context),
            body: const Center(child: Text('Customer not found')),
          );
        }

        final sales = HiveDatabase.salesBox.values
            .where((s) => s.customerId == customerId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final totalSales = sales.length;
        final totalSpent = sales.fold<double>(0, (s, sale) => s + sale.grandTotal);

        return Scaffold(
          appBar: _appBar(context, title: customer.name),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(customer),
                const SizedBox(height: 16),
                _buildStats(customer, totalSales, totalSpent),
                const SizedBox(height: 16),
                _buildInfoCard(customer, context),
                const SizedBox(height: 16),
                _buildRecentSales(sales),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, {String? title}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
        onPressed: () => context.pop(),
      ),
      title: Text(title ?? 'Customer Details',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
          onPressed: () {
            final bloc = context.read<CustomerBloc>();
            context.push('/customers/add', extra: customerId).then((_) {
              bloc.add(const LoadCustomers());
            });
          },
        ),
      ],
    );
  }

  Widget _buildHeader(Customer customer) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(customer.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(customer.phoneNumber,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStats(Customer customer, int totalSales, double totalSpent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard('Loyalty Points', '${customer.loyaltyPoints}', Icons.star, Colors.amber),
          const SizedBox(width: 8),
          _statCard('Total Spent', 'KES ${totalSpent.toStringAsFixed(0)}', Icons.money, Colors.green),
          const SizedBox(width: 8),
          _statCard('Purchases', '$totalSales', Icons.receipt, AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Customer customer, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Information',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[800])),
            const SizedBox(height: 12),
            if (customer.email != null && customer.email!.isNotEmpty)
              _infoRow(Icons.email_outlined, customer.email!),
            if (customer.address != null && customer.address!.isNotEmpty)
              _infoRow(Icons.location_on_outlined, customer.address!),
            _infoRow(Icons.calendar_today, 'Customer since ${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildRecentSales(List<SaleModel> sales) {
    if (sales.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text('No purchase history yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Purchase History (${sales.length})',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800])),
        ),
        const SizedBox(height: 8),
        ...sales.take(20).map((sale) {
          final items = sale.items.map((i) => '${i.productName} ×${i.quantity}').join(', ');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 4),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt, color: AppTheme.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sale.date.day}/${sale.date.month}/${sale.date.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(items,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Text('KES ${sale.grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
