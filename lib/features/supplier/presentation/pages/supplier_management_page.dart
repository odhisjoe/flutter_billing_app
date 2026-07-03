import 'package:billing_app/core/service_locator.dart' as di;
import 'package:billing_app/core/utils/report_exporter.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/shop/presentation/bloc/shop_bloc.dart';
import 'package:billing_app/features/supplier/domain/entities/supplier.dart';
import 'package:billing_app/features/product/presentation/bloc/product_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import 'supplier_detail_modal.dart';

class SupplierManagementPage extends StatefulWidget {
  const SupplierManagementPage({super.key});

  @override
  State<SupplierManagementPage> createState() => _SupplierManagementPageState();
}

class _SupplierManagementPageState extends State<SupplierManagementPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<SupplierBloc>().add(const LoadSuppliers());
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Supplier> _filtered(List<Supplier> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) =>
        s.name.toLowerCase().contains(q) || s.phoneNumber.contains(q)).toList();
  }

  Future<void> _export(List<Supplier> suppliers, List<int> productCounts) async {
    final shop = di.sl<ShopBloc>().state;
    final shopName = shop is ShopLoaded ? shop.shop.name : null;
    final shopAddress = shop is ShopLoaded ? shop.shop.addressLine1 : null;

    await showExportDialog(
      context,
      title: 'Supplier List',
      headers: ['Name', 'Phone', 'Email', 'Address', 'Products', 'Total Purchases', 'Amount Paid', 'Balance'],
      rows: List.generate(suppliers.length, (i) {
        final s = suppliers[i];
        return [
          s.name,
          s.phoneNumber,
          s.email ?? '',
          s.address ?? '',
          '${productCounts[i]}',
          s.totalPurchases.toStringAsFixed(2),
          s.amountPaid.toStringAsFixed(2),
          s.balance.toStringAsFixed(2),
        ];
      }),
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
        title: const Text('Suppliers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export',
                onPressed: () {
                  final supplierState = context.read<SupplierBloc>().state;
                  final list = _filtered(supplierState.suppliers);
                  if (list.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No suppliers to export')),
                    );
                    return;
                  }
                  final productBloc = context.read<ProductBloc>();
                  final counts = list.map((s) =>
                    productBloc.state.products.where((p) =>
                        p.supplier != null && p.supplier!.toLowerCase() == s.name.toLowerCase()).length
                  ).toList();
                  _export(list, counts);
                },
              ),
        ],
      ),
      body: BlocBuilder<SupplierBloc, SupplierState>(
        builder: (context, state) {
          final suppliers = _filtered(state.suppliers);
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
                      onPressed: () => showSupplierDetailModal(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${suppliers.length} supplier${suppliers.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (suppliers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No suppliers found'),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final minWidth = constraints.maxWidth < 700 ? 700.0 : constraints.maxWidth;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: minWidth,
                          child: BlocBuilder<ProductBloc, ProductState>(
                            builder: (context, productState) {
                              return Column(
                                children: [
                                  _buildHeader(minWidth),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: suppliers.length,
                                      itemBuilder: (context, index) {
                                        final s = suppliers[index];
                                        final isEven = index.isEven;
                                        final productCount = productState.products.where((p) =>
                                            p.supplier != null && p.supplier!.toLowerCase() == s.name.toLowerCase()).length;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
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
                                          child: Row(
                                            children: [
                                              _cell(s.name, 3, bold: true),
                                              _cell(s.phoneNumber, 2),
                                              _cell(s.email ?? '-', 3),
                                              _cell(s.address ?? '-', 3),
                                              _cell('$productCount', 1, center: true),
                                              _cell('KES ${s.totalPurchases.toStringAsFixed(0)}', 2, center: true),
                                              _cell('KES ${s.amountPaid.toStringAsFixed(0)}', 2, center: true),
                                              _cell(
                                                'KES ${s.balance.toStringAsFixed(0)}',
                                                2,
                                                center: true,
                                                color: s.balance > 0 ? Colors.red[700] : Colors.green[700],
                                              ),
                                              SizedBox(
                                                width: 60,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, size: 16),
                                                      onPressed: () => showSupplierDetailModal(context, supplier: s),
                                                      color: Colors.grey[600],
                                                      tooltip: 'Edit',
                                                      visualDensity: VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () => showSupplierDetailModal(context, supplier: s),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text('View', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
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
      child: Row(
        children: [
          _headerCell('Name', 3),
          _headerCell('Phone', 2),
          _headerCell('Email', 3),
          _headerCell('Address', 3),
          _headerCell('Prods', 1, center: true),
          _headerCell('Purchases', 2, center: true),
          _headerCell('Paid', 2, center: true),
          _headerCell('Balance', 2, center: true),
          SizedBox(width: 60, child: Text('Actions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _headerCell(String text, int flex, {bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]),
      ),
    );
  }

  Widget _cell(String text, int flex, {bool bold = false, bool center = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}
