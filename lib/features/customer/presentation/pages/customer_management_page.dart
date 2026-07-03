import 'package:billing_app/core/service_locator.dart' as di;
import 'package:billing_app/core/utils/report_exporter.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/customer/domain/entities/customer.dart';
import 'package:billing_app/features/shop/presentation/bloc/shop_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<CustomerBloc>().add(const LoadCustomers());
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filtered(List<Customer> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((c) =>
        c.name.toLowerCase().contains(q) || c.phoneNumber.contains(q)).toList();
  }

  Future<void> _export(List<Customer> customers) async {
    final shop = di.sl<ShopBloc>().state;
    final shopName = shop is ShopLoaded ? shop.shop.name : null;
    final shopAddress = shop is ShopLoaded ? shop.shop.addressLine1 : null;

    await showExportDialog(
      context,
      title: 'Customer List',
      headers: ['Name', 'Phone', 'Email', 'Loyalty Points', 'Total Spent'],
      rows: customers.map((c) => [
        c.name,
        c.phoneNumber,
        c.email ?? '',
        c.loyaltyPoints.toString(),
        c.totalSpent.toStringAsFixed(2),
      ]).toList(),
      shopName: shopName,
      shopAddress: shopAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, state) {
              final list = _filtered(state.customers);
              if (list.isEmpty) return const SizedBox();
              return IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export',
                onPressed: () => _export(list),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CustomerBloc, CustomerState>(
        builder: (context, state) {
          final customers = _filtered(state.customers);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon:
                              Icon(Icons.search, color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/customers/add'),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${customers.length} customer${customers.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (customers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No customers found'),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < 640
                          ? 640.0
                          : constraints.maxWidth;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            children: [
                              _buildHeader(tableWidth),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: customers.length,
                                  itemBuilder: (context, index) {
                                    final c = customers[index];
                                    final isEven = index.isEven;
                                    return GestureDetector(
                                      onTap: () => context.push(
                                          '/customers/detail/${c.id}'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isEven
                                              ? Colors.grey[50]
                                              : Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                                color: Colors.grey[200]!,
                                                width: 1),
                                          ),
                                        ),
                                        child: _responsiveRow(tableWidth, [
                                          (c.name, 140, 35),
                                          (c.phoneNumber, 120, 30),
                                          (c.email ?? '-', 136, 34),
                                          ('${c.loyaltyPoints} pts', 100, 25),
                                          ('KES ${c.totalSpent
                                              .toStringAsFixed(0)}', 120, 30),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(double tableWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: _responsiveRow(tableWidth, [
        ('Name', 140, 35),
        ('Phone', 120, 30),
        ('Email', 136, 34),
        ('Points', 100, 25),
        ('Total Spent', 120, 30),
      ], isHeader: true),
    );
  }

  Widget _responsiveRow(double tableWidth, List<(String text, double minWidth, int flex)> cells, {bool isHeader = false}) {
    return Row(
      children: cells.map((c) {
        return Expanded(
          flex: c.$3,
          child: Text(c.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: isHeader ? 11 : 12,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: isHeader ? Colors.grey[700] : Colors.black87)),
        );
      }).toList(),
    );
  }
}
