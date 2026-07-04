import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/barcode_scanner_service.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/data/models/product_model.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/inventory_transaction_model.dart';

class PurchaseReceivingPage extends StatefulWidget {
  const PurchaseReceivingPage({super.key});

  @override
  State<PurchaseReceivingPage> createState() => _PurchaseReceivingPageState();
}

class _PurchaseReceivingPageState extends State<PurchaseReceivingPage> {
  final _searchController = TextEditingController();
  String _query = '';
  final _qtyControllers = <String, TextEditingController>{};
  final _scrollController = ScrollController();
  String? _highlightedProductId;
  String? _selectedAdminId;
  StreamSubscription<String>? _barcodeSub;

  List<UserModel> get _admins =>
      HiveDatabase.usersBox.values.where((u) => u.role.name == 'admin' || u.role.name == 'superAdmin').toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
    _barcodeSub = BarcodeScannerService().onBarcodeScanned.listen(_handleBarcodeInput);
  }

  void _handleBarcodeInput(String barcode) {
    if (!mounted) return;
    final state = context.read<ProductBloc>().state;
    final product = state.products.cast<Product?>().firstWhere(
      (p) => p!.barcode == barcode,
      orElse: () => null,
    );
    if (product == null) return;
    context.push('/products/edit/${product.id}', extra: product);
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode = await context.push<String>('/scanner');
    if (barcode == null || !mounted) return;

    final state = context.read<ProductBloc>().state;
    final product = state.products.cast<Product?>().firstWhere(
      (p) => p!.barcode == barcode,
      orElse: () => null,
    );

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found with barcode "$barcode"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (mounted) {
      await context.push('/products/edit/${product.id}', extra: product);
    }
  }

  String? _adminName(String? id) {
    if (id == null) return null;
    try {
      return HiveDatabase.usersBox.get(id)?.name;
    } catch (_) {
      return null;
    }
  }

  Future<void> _receiveStock(Product product) async {
    final ctrl = _qtyControllers[product.id];
    if (ctrl == null) return;
    final qty = int.tryParse(ctrl.text.trim());
    if (qty == null || qty <= 0) return;

    final newStock = product.stock + qty;
    final updated = product.copyWith(stock: newStock, assignedTo: _selectedAdminId ?? product.assignedTo);
    final model = ProductModel.fromEntity(updated);
    await HiveDatabase.productBox.put(model.id, model);

    await HiveDatabase.inventoryBox.put(
      const Uuid().v4(),
      InventoryTransactionModel(
        id: const Uuid().v4(), productId: product.id,
        productName: product.name, type: 'purchase_in',
        quantity: qty, stockBefore: product.stock,
        stockAfter: newStock, timestamp: DateTime.now(),
        assignedTo: _selectedAdminId ?? product.assignedTo,
      ),
    );

    if (!mounted) return;
    context.read<ProductBloc>().add(const LoadProducts());
    ctrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Received $qty × ${product.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = _admins;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Receive Stock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (admins.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAdminId,
                        isExpanded: true,
                        hint: Text('Assign to admin...', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text('All admins', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                          ...admins.map((u) => DropdownMenuItem(value: u.id, child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(u.name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ),
                              const SizedBox(width: 8),
                              Text(u.name, style: const TextStyle(fontSize: 13)),
                            ],
                          ))),
                        ],
                        onChanged: (v) => setState(() => _selectedAdminId = v),
                      ),
                    ),
                  ),
                  if (_selectedAdminId != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedAdminId = null),
                      child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search product by name, barcode or SKU...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                    tooltip: 'Scan barcode to find product',
                    onPressed: _scanBarcode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state.status == ProductStatus.loading && state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                var products = state.products.where((p) {
                  final matchesSearch = p.name.toLowerCase().contains(_query) ||
                      p.barcode.toLowerCase().contains(_query) ||
                      (p.sku?.toLowerCase().contains(_query) ?? false);
                  if (!matchesSearch) return false;
                  if (_selectedAdminId != null && p.assignedTo != null && p.assignedTo != _selectedAdminId) return false;
                  return true;
                }).toList()..sort((a, b) => a.name.compareTo(b.name));

                return products.isEmpty
                    ? Center(child: Text('No products found', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          _qtyControllers.putIfAbsent(product.id, () => TextEditingController());
                          final isHighlighted = _highlightedProductId == product.id;
                          final assignedName = _adminName(product.assignedTo);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: isHighlighted ? Colors.teal.withValues(alpha: 0.08) : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => context.push('/products/edit/${product.id}', extra: product),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child:                                                     Text(product.name,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit_outlined, size: 12, color: Colors.grey[400]),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text('Stock: ${product.stock} | Barcode: ${product.barcode}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller: _qtyControllers[product.id],
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              hintText: 'Qty',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _receiveStock(product),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Receive', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    if (assignedName != null || _selectedAdminId != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.person_outline, size: 12, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedAdminId != null
                                                  ? 'Assigning to: ${_adminName(_selectedAdminId) ?? "Selected"}'
                                                  : 'Assigned: $assignedName',
                                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
