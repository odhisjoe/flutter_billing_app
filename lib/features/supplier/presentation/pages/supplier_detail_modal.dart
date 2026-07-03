import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/supplier.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/domain/usecases/product_usecases.dart';
import '../../../../core/service_locator.dart' as di;
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';

Future<void> showSupplierDetailModal(BuildContext context, {Supplier? supplier}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<SupplierBloc>()),
        BlocProvider.value(value: context.read<ProductBloc>()),
      ],
      child: _SupplierDetailModal(supplier: supplier),
    ),
  );
}

class _SupplierDetailModal extends StatefulWidget {
  final Supplier? supplier;
  const _SupplierDetailModal({this.supplier});

  @override
  State<_SupplierDetailModal> createState() => _SupplierDetailModalState();
}

class _SupplierDetailModalState extends State<_SupplierDetailModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _totalPurchasesCtrl = TextEditingController();
  final _amountPaidCtrl = TextEditingController();
  bool _showDeleteConfirm = false;
  Set<String> _linkedProductIds = <String>{};

  bool get _isEditing => widget.supplier != null;
  Supplier? get _supplier => widget.supplier;

  @override
  void initState() {
    super.initState();
    final productBloc = context.read<ProductBloc>();
    if (productBloc.state.status != ProductStatus.loaded) {
      productBloc.add(const LoadProducts());
    }
    if (_isEditing) _populate(_supplier!);
  }

  void _populate(Supplier s) {
    _nameCtrl.text = s.name;
    _phoneCtrl.text = s.phoneNumber;
    _emailCtrl.text = s.email ?? '';
    _addressCtrl.text = s.address ?? '';
    _totalPurchasesCtrl.text = s.totalPurchases > 0 ? s.totalPurchases.toStringAsFixed(2) : '';
    _amountPaidCtrl.text = s.amountPaid > 0 ? s.amountPaid.toStringAsFixed(2) : '';
    _initLinkedProducts(s.name);
  }

  void _initLinkedProducts(String supplierName) {
    final productBloc = context.read<ProductBloc>();
    final linked = productBloc.state.products
        .where((p) => (p.supplier ?? '').toLowerCase() == supplierName.toLowerCase())
        .map((p) => p.id)
        .toSet();
    _linkedProductIds = linked;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _totalPurchasesCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final supplierName = _nameCtrl.text.trim();
    final supplier = Supplier(
      id: _isEditing ? _supplier!.id : const Uuid().v4(),
      name: supplierName,
      phoneNumber: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      createdAt: _isEditing ? _supplier!.createdAt : DateTime.now(),
      totalPurchases: double.tryParse(_totalPurchasesCtrl.text.trim()) ?? 0,
      amountPaid: double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
    );

    if (_isEditing) {
      context.read<SupplierBloc>().add(UpdateSupplier(supplier));
    } else {
      context.read<SupplierBloc>().add(AddSupplier(supplier));
    }

    _syncProductSuppliers(supplierName);
    Navigator.pop(context);
  }

  void _syncProductSuppliers(String supplierName) {
    final productBloc = context.read<ProductBloc>();
    final repo = di.sl<UpdateProductUseCase>();
    for (final product in productBloc.state.products) {
      final isLinked = _linkedProductIds.contains(product.id);
      final currentSupplier = product.supplier ?? '';
      if (isLinked && currentSupplier.toLowerCase() != supplierName.toLowerCase()) {
        repo(product.copyWith(supplier: supplierName));
      } else if (!isLinked && currentSupplier.toLowerCase() == supplierName.toLowerCase()) {
        repo(product.copyWith(supplier: null));
      }
    }
  }

  void _delete() {
    context.read<SupplierBloc>().add(DeleteSupplier(_supplier!.id));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxW = screenW < 600 ? screenW * 0.95 : 520.0;
    return Dialog(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: screenH * 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.business, color: Colors.teal[700], size: 20),
                ),
                const SizedBox(width: 10),
                Text(_isEditing ? 'Supplier Details' : 'New Supplier',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Supplier Name *',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone *',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _addressCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Address',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Financial & Supply Summary ---
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, state) {
                        final supplierName = _isEditing ? _supplier!.name : _nameCtrl.text.trim();
                        final linkedProducts = state.products.where((p) =>
                            (p.supplier ?? '').toLowerCase() == supplierName.toLowerCase()).toList();
                        final fromSelection = state.products.where((p) => _linkedProductIds.contains(p.id)).toList();
                        final displayProducts = _isEditing ? linkedProducts : fromSelection;
                        final totalQty = displayProducts.fold<int>(0, (sum, p) => sum + p.stock);
                        final totalValue = displayProducts.fold<double>(0, (sum, p) => sum + p.buyingPrice * p.stock);
                        final purchases = _isEditing ? _supplier!.totalPurchases : double.tryParse(_totalPurchasesCtrl.text.trim()) ?? 0;
                        final paid = _isEditing ? _supplier!.amountPaid : double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
                        final bal = purchases - paid;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.teal[50]!, Colors.teal[100]!]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, size: 16, color: Colors.teal[700]),
                                  const SizedBox(width: 6),
                                  Text('Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[900])),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _financeTile('Total Purchases', purchases, Colors.teal, Icons.shopping_cart),
                                  const SizedBox(width: 8),
                                  _financeTile('Amount Paid', paid, Colors.blue, Icons.payments),
                                  const SizedBox(width: 8),
                                  _financeTile('Balance', bal, bal > 0 ? Colors.red : Colors.green, Icons.balance),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2, size: 14, color: Colors.teal[600]),
                                    const SizedBox(width: 6),
                                    Text('${displayProducts.length} product${displayProducts.length == 1 ? '' : 's'} supplied',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.teal[800])),
                                    const Spacer(),
                                    Text('$totalQty units  ·  KES ${totalValue.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal[800])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, size: 14, color: Colors.teal[600]),
                          const SizedBox(width: 6),
                          Text('Update financial records', style: TextStyle(fontSize: 11, color: Colors.teal[700])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _totalPurchasesCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Total Purchases (KES)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountPaidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Amount Paid (KES)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- Link Products Section ---
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text('Products Supplied', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Link product button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 14),
                        label: Text(
                          _linkedProductIds.isEmpty ? 'Link Products to Supplier' : 'Manage Linked Products',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: _showProductLinker,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (_linkedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      BlocBuilder<ProductBloc, ProductState>(
                        builder: (context, state) {
                          final products = state.products.where((p) => _linkedProductIds.contains(p.id)).toList();
                          if (products.isEmpty) return const SizedBox();
                          final totalValue = products.fold<double>(0, (sum, p) => sum + p.buyingPrice * p.stock);
                          final totalQty = products.fold<int>(0, (sum, p) => sum + p.stock);

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey[600]))),
                                    Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey[600]))),
                                    Expanded(flex: 2, child: Text('Cost', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey[600]))),
                                    Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey[600]))),
                                    const SizedBox(width: 20),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...products.map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text('${p.stock}', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.stock > 0 ? Colors.teal[700] : Colors.red))),
                                        Expanded(flex: 2, child: Text('KES ${p.buyingPrice.toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                                        Expanded(flex: 2, child: Text('KES ${(p.buyingPrice * p.stock).toStringAsFixed(0)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                                        SizedBox(
                                          width: 20,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _linkedProductIds.remove(p.id)),
                                            child: Icon(Icons.close, size: 14, color: Colors.red[300]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('${products.length} products', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
                                    Expanded(flex: 2, child: Text('$totalQty', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
                                    const Expanded(flex: 2, child: SizedBox.shrink()),
                                    Expanded(flex: 2, child: Text('KES ${totalValue.toStringAsFixed(0)}', textAlign: TextAlign.end, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
                                    const SizedBox(width: 20),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, size: 14, color: Colors.red[400]),
                      label: Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red[400])),
                      onPressed: () => setState(() => _showDeleteConfirm = true),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[200]!),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (_isEditing) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(_isEditing ? 'Update' : 'Save', style: const TextStyle(fontSize: 12)),
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            if (_showDeleteConfirm)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Delete this supplier?', style: TextStyle(fontSize: 12))),
                    TextButton(
                      child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _showDeleteConfirm = false),
                    ),
                    TextButton(
                      onPressed: _delete,
                      child: Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red[600])),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showProductLinker() {
    final productBloc = context.read<ProductBloc>();
    if (productBloc.state.status != ProductStatus.loaded) {
      productBloc.add(const LoadProducts());
    }

    final searchCtrl = TextEditingController();
    String query = '';

    showDialog(
      context: context,
      builder: (ctx) {
        final selected = Set<String>.from(_linkedProductIds);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allProducts = productBloc.state.products;
            final filtered = allProducts.where((p) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.barcode.toLowerCase().contains(q) ||
                  (p.sku ?? '').toLowerCase().contains(q);
            }).toList();

            filtered.sort((a, b) {
              final aLinked = selected.contains(a.id);
              final bLinked = selected.contains(b.id);
              if (aLinked && !bLinked) return -1;
              if (!aLinked && bLinked) return 1;
              return a.name.compareTo(b.name);
            });

            return AlertDialog(
              title: const Text('Link Products'),
              content: SizedBox(
                width: double.maxFinite,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, barcode or SKU...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setDialogState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${selected.length} linked',
                            style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('${filtered.length} products',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                query.isEmpty ? 'No products in inventory' : 'No products matching "$query"',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final isChecked = selected.contains(p.id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: isChecked,
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (v == true) {
                                        selected.add(p.id);
                                      } else {
                                        selected.remove(p.id);
                                      }
                                    });
                                  },
                                  title: Text(p.name, style: const TextStyle(fontSize: 12)),
                                  subtitle: Text(
                                    'Stock: ${p.stock}  ·  KES ${p.buyingPrice.toStringAsFixed(0)}${p.supplier != null ? '  ·  ${p.supplier}' : ''}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    searchCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _linkedProductIds = selected);
                    searchCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: Text('Done (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      searchCtrl.dispose();
    });
  }

  Widget _financeTile(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Text('KES ${amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
