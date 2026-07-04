import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:billing_app/core/utils/report_exporter.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:flutter/material.dart';

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _allProducts = HiveDatabase.productBox.values
          .map((m) => m.toEntity())
          .toList();
    });
  }

  List<String> get _categories {
    final cats =
        _allProducts.map((p) => p.category).whereType<String>().toSet().toList();
    cats.sort();
    return cats;
  }

  List<Product> get _filteredProducts {
    var filtered = _allProducts;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(_searchQuery) ||
          p.barcode.toLowerCase().contains(_searchQuery)).toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered
          .where((p) => p.category == _selectedCategory)
          .toList();
    }
    return filtered;
  }

  double get _totalValue =>
      _filteredProducts.fold(0.0, (sum, p) => sum + p.price * p.stock);

  int get _totalStock =>
      _filteredProducts.fold(0, (sum, p) => sum + p.stock);

  Color _stockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  Future<void> _export() async {
    final shop = HiveDatabase.shopBox.values.isNotEmpty
        ? HiveDatabase.shopBox.values.first
        : null;
    final rows = _filteredProducts.map((p) => [
      p.name,
      p.barcode,
      p.category ?? '-',
      '${p.stock}',
      p.buyingPrice > 0 ? AppConstants.formatPrice(p.buyingPrice) : '-',
      AppConstants.formatPrice(p.price),
      AppConstants.formatPrice(p.price * p.stock),
    ]).toList();

    rows.add([
      'TOTAL', '', '', '$_totalStock',
      '', '',
      AppConstants.formatPrice(_totalValue),
    ]);

    showExportDialog(
      context,
      title: 'Inventory Report',
      headers: ['Product', 'Barcode', 'Category', 'Stock', 'Cost', 'Sell', 'Value'],
      rows: rows,
      shopName: shop?.name,
      shopAddress: shop?.addressLine1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Report',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_filteredProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export',
              onPressed: _export,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or barcode...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCategoryFilter(),
                ),
                if (_selectedCategory != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _selectedCategory = null),
                      child:
                          const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '$_filteredProducts.length product${_filteredProducts.length == 1 ? '' : 's'} | '
                  '$_totalStock units | Value: ${AppConstants.formatPrice(_totalValue)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Text('No products',
                        style: TextStyle(color: Colors.grey[400])))
                  : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                      child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.of(context).size.width;
                        final tableWidth = availableWidth > 720 ? availableWidth : 720.0;
                        final scale = tableWidth / 720;
                        return Column(
                          children: [
                            _buildHeader(scale),
                            Expanded(
                              child: SizedBox(
                              width: tableWidth,
                              child: ListView.builder(
                                  itemCount: _filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = _filteredProducts[index];
                                    final isEven = index.isEven;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isEven
                                            ? Colors.grey[50]
                                            : Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey[200]!, width: 1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _td(product.name, 160 * scale),
                                          _td(product.barcode, 100 * scale,
                                              mono: true),
                                          _td(
                                              product.category ??
                                                  '-',
                                              90 * scale),
                                          SizedBox(
                                            width: 70 * scale,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _stockColor(product.stock),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text('${product.stock}',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[700])),
                                              ],
                                            ),
                                          ),
                                          _td(
                                              product.buyingPrice > 0
                                                  ? 'KES ${product.buyingPrice.toStringAsFixed(0)}'
                                                  : '-',
                                              80 * scale),
                                          _td(
                                              'KES ${product.price.toStringAsFixed(0)}',
                                              80 * scale,
                                              bold: true),
                                          _td(
                                              AppConstants.formatPrice(
                                                  product.price * product.stock),
                                              100 * scale,
                                              bold: true),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final cats = _categories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          hint: Text('All Categories',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('All Categories',
                    style: TextStyle(fontSize: 13))),
            ...cats.map((cat) => DropdownMenuItem(
                value: cat,
                child:
                    Text(cat, style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: (val) => setState(() => _selectedCategory = val),
        ),
      ),
    );
  }

  Widget _buildHeader(double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: SizedBox(
        width: 720 * scale,
        child: Row(
          children: [
            _th('Product', 160 * scale),
            _th('Barcode', 100 * scale),
            _th('Category', 90 * scale),
            _th('Stock', 70 * scale),
            _th('Cost', 80 * scale),
            _th('Sell', 80 * scale),
            _th('Value', 100 * scale),
          ],
        ),
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

  Widget _td(String text, double width,
      {bool mono = false, bool bold = false}) {
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
}
