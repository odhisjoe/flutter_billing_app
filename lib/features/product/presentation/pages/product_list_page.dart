import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../../inventory/data/models/inventory_transaction_model.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedStockStatus;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      final query = _searchController.text.toLowerCase();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _searchQuery = query);
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode == barcode).firstOrNull;
      if (matchedProduct != null) {
        _searchController.text = matchedProduct.name;
      } else {
        _searchController.text = barcode;
      }
    }
  }

  Color _stockStatusColor(Product product) {
    if (product.stock <= 0) return Colors.red;
    if (product.minStockLevel > 0 && product.stock <= product.minStockLevel) return Colors.orange;
    return Colors.green;
  }

  bool _matchesStockStatus(Product product, String? status) {
    if (status == null || status == 'All') return true;
    if (status == 'In Stock') {
      if (product.minStockLevel > 0) return product.stock > product.minStockLevel;
      return product.stock > 10;
    }
    if (status == 'Low Stock') {
      if (product.minStockLevel > 0) return product.stock > 0 && product.stock <= product.minStockLevel;
      return product.stock > 0 && product.stock <= 10;
    }
    if (status == 'Out of Stock') return product.stock <= 0;
    return true;
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery) ||
          product.barcode.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == null ||
          product.category == _selectedCategory;
      final matchesStock = _matchesStockStatus(product, _selectedStockStatus);
      return matchesSearch && matchesCategory && matchesStock;
    }).toList();
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    String content;
    if (kIsWeb) {
      content = utf8.decode(result.files.single.bytes!);
    } else {
      content = await File(result.files.single.path!).readAsString();
    }

    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV must have a header row and at least one data row'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final headers = _parseCsvLine(lines[0]);
    final nameIdx = headers.indexWhere((h) => h.toLowerCase() == 'name');
    final barcodeIdx = headers.indexWhere((h) => h.toLowerCase() == 'barcode');
    final priceIdx = headers.indexWhere((h) => h.toLowerCase() == 'price' || h.toLowerCase() == 'selling price');
    final stockIdx = headers.indexWhere((h) => h.toLowerCase() == 'stock' || h.toLowerCase() == 'quantity');
    final categoryIdx = headers.indexWhere((h) => h.toLowerCase() == 'category');
    final skuIdx = headers.indexWhere((h) => h.toLowerCase() == 'sku');
    final buyingPriceIdx = headers.indexWhere((h) => h.toLowerCase() == 'buying price' || h.toLowerCase() == 'cost');
    final supplierIdx = headers.indexWhere((h) => h.toLowerCase() == 'supplier');
    final imageIdx = headers.indexWhere((h) => h.toLowerCase() == 'image url' || h.toLowerCase() == 'image');

    if (nameIdx < 0 || barcodeIdx < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV must have at least "name" and "barcode" columns'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    int added = 0, skipped = 0;
    final errors = <String>[];
    final existingBarcodes =
        context.read<ProductBloc>().state.products.map((p) => p.barcode).toSet();

    for (int i = 1; i < lines.length; i++) {
      try {
        final fields = _parseCsvLine(lines[i]);
        if (fields.length <= nameIdx || fields.length <= barcodeIdx) {
          skipped++;
          continue;
        }
        final barcode = fields[barcodeIdx].trim();
        if (barcode.isEmpty || existingBarcodes.contains(barcode)) {
          skipped++;
          continue;
        }
        existingBarcodes.add(barcode);

        final name = fields[nameIdx].trim();
        if (name.isEmpty) {
          skipped++;
          continue;
        }

        final product = Product(
          id: const Uuid().v4(),
          name: name,
          barcode: barcode,
          price: priceIdx >= 0 ? double.tryParse(fields[priceIdx].trim()) ?? 0 : 0,
          stock: stockIdx >= 0 ? int.tryParse(fields[stockIdx].trim()) ?? 0 : 0,
          category: categoryIdx >= 0 && fields[categoryIdx].trim().isNotEmpty
              ? fields[categoryIdx].trim()
              : 'General',
          imageUrl: imageIdx >= 0 && fields[imageIdx].trim().isNotEmpty
              ? fields[imageIdx].trim()
              : null,
          sku: skuIdx >= 0 && fields[skuIdx].trim().isNotEmpty
              ? fields[skuIdx].trim()
              : null,
          buyingPrice: buyingPriceIdx >= 0
              ? double.tryParse(fields[buyingPriceIdx].trim()) ?? 0
              : 0,
          supplier: supplierIdx >= 0 && fields[supplierIdx].trim().isNotEmpty
              ? fields[supplierIdx].trim()
              : null,
        );

        context.read<ProductBloc>().add(AddProduct(product));
        added++;
      } catch (e) {
        errors.add('Row ${i + 1}: $e');
        skipped++;
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Added: $added products'),
              Text('Skipped: $skipped'),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Errors (${errors.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ...errors.take(5).map((e) => Text(e,
                    style: TextStyle(fontSize: 11, color: Colors.red[600]))),
                if (errors.length > 5)
                  Text('...and ${errors.length - 5} more',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  Future<void> _recordTransaction(Product product, String type, int qty, int before, {String? reference, String? notes}) async {
    final model = InventoryTransactionModel(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.name,
      type: type,
      quantity: qty,
      stockBefore: before,
      stockAfter: before + qty,
      reference: reference,
      notes: notes,
      timestamp: DateTime.now(),
      assignedTo: product.assignedTo,
    );
    await HiveDatabase.inventoryBox.put(model.id, model);
  }

  Future<void> _updateStock(Product product, int newStock) async {
    final updated = product.copyWith(stock: newStock);
    context.read<ProductBloc>().add(UpdateProduct(updated));
  }

  void _showAdjustStockDialog(Product product) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${product.name}', style: const TextStyle(fontSize: 13)),
            Text('Current Stock: ${product.stock}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
              decoration: const InputDecoration(
                hintText: 'e.g. +10 or -5',
                labelText: 'Adjustment Quantity',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text.trim());
              if (qty == null || qty == 0) return;
              final newStock = product.stock + qty;
              await _updateStock(product, newStock);
              await _recordTransaction(product, 'adjustment', qty, product.stock);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReceiveStockDialog(Product product) {
    final controller = TextEditingController();
    final refController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${product.name}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Quantity received', labelText: 'Quantity', isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: refController,
              decoration: const InputDecoration(hintText: 'PO # or invoice', labelText: 'Reference', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text.trim());
              if (qty == null || qty <= 0) return;
              final newStock = product.stock + qty;
              await _updateStock(product, newStock);
              await _recordTransaction(product, 'purchase_in', qty, product.stock, reference: refController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Receive', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMarkDamagedDialog(Product product) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Damaged'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${product.name}', style: const TextStyle(fontSize: 13)),
            Text('Current Stock: ${product.stock}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Quantity damaged', labelText: 'Qty Damaged', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text.trim());
              if (qty == null || qty <= 0 || qty > product.stock) return;
              final newStock = product.stock - qty;
              await _updateStock(product, newStock);
              await _recordTransaction(product, 'damaged', -qty, product.stock);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(Icons.inventory_2, color: Colors.grey[400], size: 22);
    }
    final isNetwork = kIsWeb ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:');
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isNetwork
          ? Image.network(imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.inventory_2, color: Colors.grey[400], size: 22))
          : Image.file(File(imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.inventory_2, color: Colors.grey[400], size: 22)),
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
        title: const Text('Products',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/products/add'),
          ),
        ],
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state.status == ProductStatus.success && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message!),
                  backgroundColor: Colors.green),
            );
          } else if (state.status == ProductStatus.error &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message!),
                  backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.status == ProductStatus.loading && state.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.products.isEmpty) {
            if (state.status == ProductStatus.error) {
              return Center(child: Text('Error: ${state.message}'));
            }
            return const Center(
                child: Text('No products found. Add some!'));
          }

          final categories = state.products
              .map((p) => p.category ?? 'General')
              .toSet()
              .toList()
            ..sort();
          final filteredProducts = _filterProducts(state.products);

          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Catalog',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                        'Manage and organize your store\'s inventory items.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),

              // Search + Actions
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _searchController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                                  onPressed: () => _scanQR(state.products),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/products/add'),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Product'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _importCsv,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Import CSV'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.primaryColor),
                                  foregroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _searchController,
                                      textCapitalization: TextCapitalization.words,
                                      decoration: InputDecoration(
                                        hintText: 'Search products...',
                                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                                      onPressed: () => _scanQR(state.products),
                                      padding: const EdgeInsets.all(12),
                                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.push('/products/add'),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _importCsv,
                                      icon: const Icon(Icons.upload_file, size: 18),
                                      label: const Text('Import'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: AppTheme.primaryColor),
                                        foregroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  );
                },
              ),

              // Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedCategory,
                        hint: 'All Categories',
                        items: categories
                            .map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategory = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedStockStatus,
                        hint: 'All Stock',
                        items: const [
                          DropdownMenuItem(
                              value: 'In Stock',
                              child: Text('In Stock',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'Low Stock',
                              child: Text('Low Stock',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'Out of Stock',
                              child: Text('Out of Stock',
                                  style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedStockStatus = val),
                      ),
                    ),
                    if (_selectedCategory != null ||
                        _selectedStockStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedStockStatus = null;
                            });
                          },
                          child: const Text('Clear',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filteredProducts.length} product${filteredProducts.length == 1 ? '' : 's'} found',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Product Table
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products match your criteria.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = math.max(
                              constraints.maxWidth, 810.0);
                          final scale = tableWidth / 810;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.08),
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _th('No.', 36 * scale),
                                        _th('Product', 160 * scale),
                                        _th('Barcode', 100 * scale),
                                        _th('SKU', 80 * scale),
                                        _th('Category', 90 * scale),
                                        _th('Cost', 80 * scale),
                                        _th('Sell', 80 * scale),
                                        _th('Stock', 56 * scale),
                                        _th('Actions', 104 * scale),
                                      ],
                                    ),
                                  ),
                                  // Table Rows
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: filteredProducts.length,
                                      itemBuilder: (context, index) {
                                        final product =
                                            filteredProducts[index];
                                        final isEven = index.isEven;
                                        return Container(
                                          key: ValueKey(product.id),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10),
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
                                              _td('${index + 1}',
                                                  36 * scale),
                                              SizedBox(
                                                width: 160 * scale,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            Colors.grey[100],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child:
                                                          _buildThumbnail(
                                                              product
                                                                  .imageUrl),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    Expanded(
                                                      child: Text(
                                                          product.name,
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            fontSize: 12,
                                                          )),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _td(product.barcode,
                                                  100 * scale,
                                                  mono: true),
                                              _td(product.sku ?? '-',
                                                  80 * scale,
                                                  mono: true),
                                              _td(
                                                  product.category !=
                                                              null &&
                                                          product.category !=
                                                              'General'
                                                      ? product.category!
                                                      : '-',
                                                  90 * scale),
                                              _td(
                                                  product.buyingPrice > 0
                                                      ? 'KES ${product.buyingPrice.toStringAsFixed(0)}'
                                                      : '-',
                                                  80 * scale),
                                              _td(
                                                  'KES ${product.price.toStringAsFixed(0)}',
                                                  80 * scale,
                                                  bold: true),
                                              SizedBox(
                                                width: 56 * scale,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 7,
                                                      height: 7,
                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            _stockStatusColor(
                                                                product),
                                                        shape: BoxShape
                                                            .circle,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 4),
                                                    Text(
                                                        '${product.stock}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[700])),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: 104 * scale,
                                                child: Row(
                                                  children: [
                                                    _actionButton(
                                                      Icons.edit_outlined,
                                                      AppTheme.primaryColor,
                                                      () => context.push(
                                                          '/products/edit/${product.id}',
                                                          extra: product),
                                                    ),
                                                    const SizedBox(
                                                        width: 4),
                                                    _actionButton(
                                                      Icons
                                                          .delete_outline,
                                                      Colors.red[400]!,
                                                      () =>
                                                          _confirmDelete(
                                                              context,
                                                              product),
                                                    ),
                                                    const SizedBox(
                                                        width: 4),
                                                    PopupMenuButton<
                                                        String>(
                                                      onSelected:
                                                          (value) {
                                                        switch (value) {
                                                          case 'adjust':
                                                            _showAdjustStockDialog(
                                                                product);
                                                            break;
                                                          case 'receive':
                                                            _showReceiveStockDialog(
                                                                product);
                                                            break;
                                                          case 'damaged':
                                                            _showMarkDamagedDialog(
                                                                product);
                                                            break;
                                                        }
                                                      },
                                                      itemBuilder: (_) =>
                                                          const [
                                                        PopupMenuItem(
                                                            value: 'adjust',
                                                            child: Text(
                                                                'Adjust Stock',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13))),
                                                        PopupMenuItem(
                                                            value: 'receive',
                                                            child: Text(
                                                                'Receive Stock',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13))),
                                                        PopupMenuItem(
                                                            value: 'damaged',
                                                            child: Text(
                                                                'Mark Damaged',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13))),
                                                      ],
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey[100],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      6),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                    .all(2),
                                                        child: Icon(
                                                            Icons
                                                                .more_horiz,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600]),
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

  Widget _th(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700])),
    );
  }

  Widget _td(String text, double width, {bool mono = false, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87)),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: color,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: const EdgeInsets.all(4),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          isDense: true,
          isExpanded: true,
          items: [
            DropdownMenuItem(
                value: null,
                child: Text(hint, style: const TextStyle(fontSize: 13))),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
