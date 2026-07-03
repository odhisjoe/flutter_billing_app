import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/usecase/usecase.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:billing_app/core/utils/report_exporter.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/reports/domain/entities/sale.dart';
import 'package:billing_app/features/reports/domain/usecases/sale_usecases.dart';
import 'package:flutter/material.dart';

class ProfitAnalysisReportPage extends StatefulWidget {
  const ProfitAnalysisReportPage({super.key});

  @override
  State<ProfitAnalysisReportPage> createState() =>
      _ProfitAnalysisReportPageState();
}

class _ProfitAnalysisReportPageState extends State<ProfitAnalysisReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Sale> _allSales = [];
  bool _loading = true;

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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final useCase = sl<GetAllSalesUseCase>();
      final result = await useCase(NoParams());
      result.fold(
        (_) => _allSales = [],
        (sales) => _allSales = sales,
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<_ProfitLineItem> get _lineItems {
    final items = <_ProfitLineItem>[];
    for (final sale in _allSales) {
      for (final item in sale.items) {
        final profit = (item.unitPrice - item.buyingPrice) * item.quantity;
        items.add(_ProfitLineItem(
          date: sale.date,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          buyingPrice: item.buyingPrice,
          profit: profit,
          cashierName: sale.cashierName,
        ));
      }
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  List<_ProfitLineItem> get _filteredItems {
    final items = _lineItems;
    if (_searchQuery.isEmpty) return items;
    return items.where((i) =>
        i.productName.toLowerCase().contains(_searchQuery)).toList();
  }

  double get _totalProfit =>
      _filteredItems.fold(0.0, (sum, i) => sum + i.profit);

  Future<void> _export() async {
    final shop = HiveDatabase.shopBox.values.isNotEmpty
        ? HiveDatabase.shopBox.values.first
        : null;
    final rows = _filteredItems.map((i) => [
      _formatDate(i.date),
      i.productName,
      '${i.quantity}',
      AppConstants.formatPrice(i.unitPrice),
      AppConstants.formatPrice(i.buyingPrice),
      AppConstants.formatPrice(i.profit),
      i.cashierName ?? '-',
    ]).toList();

    rows.add([
      'Total Profit', '', '', '', '', '',
      AppConstants.formatPrice(_totalProfit),
    ]);

    showExportDialog(
      context,
      title: 'Profit Analysis Report',
      headers: ['Date/Time', 'Product', 'Qty', 'Sell Price', 'Cost Price', 'Profit', 'Cashier'],
      rows: rows,
      shopName: shop?.name,
      shopAddress: shop?.addressLine1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Analysis',
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
          if (_filteredItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export',
              onPressed: _export,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by product name...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredItems.length} line${_filteredItems.length == 1 ? '' : 's'} | '
                        'Total Profit: ${AppConstants.formatPrice(_totalProfit)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Text('No profit data',
                              style: TextStyle(color: Colors.grey[400])))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth.isFinite
                                  ? constraints.maxWidth
                                  : MediaQuery.of(context).size.width;
                              final tableWidth =
                                  availableWidth > 820
                                      ? availableWidth
                                      : 820.0;
                              final scale = tableWidth / 820;
                              return Column(
                                children: [
                                  _buildHeader(tableWidth, scale),
                                  Expanded(
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: ListView.builder(
                                        itemCount: _filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _filteredItems[index];
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
                                                    color: Colors.grey[200]!,
                                                    width: 1),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _td(_formatDate(item.date), 120 * scale),
                                                _td(item.productName, 160 * scale),
                                                _td('${item.quantity}', 50 * scale),
                                                _td(
                                                    AppConstants.formatPrice(
                                                        item.unitPrice),
                                                    90 * scale),
                                                _td(
                                                    AppConstants.formatPrice(
                                                        item.buyingPrice),
                                                    90 * scale),
                                                _td(
                                                    AppConstants.formatPrice(
                                                        item.profit),
                                                    100 * scale,
                                                    bold: true,
                                                    profit: true),
                                                _td(item.cashierName ?? '-',
                                                    100 * scale),
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

  Widget _buildHeader(double tableWidth, double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: SizedBox(
        width: tableWidth,
        child: Row(
          children: [
            _th('Date/Time', 120 * scale),
            _th('Product', 160 * scale),
            _th('Qty', 50 * scale),
            _th('Sell Price', 90 * scale),
            _th('Cost Price', 90 * scale),
            _th('Profit', 100 * scale),
            _th('Cashier', 100 * scale),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
      {bool bold = false, bool profit = false}) {
    final isProfit = profit && text.startsWith('KES');
    Color? color;
    if (isProfit) {
      final val = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (val != null) color = val >= 0 ? Colors.green[700] : Colors.red;
    }
    return SizedBox(
      width: width,
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? Colors.black87)),
    );
  }
}

class _ProfitLineItem {
  final DateTime date;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double buyingPrice;
  final double profit;
  final String? cashierName;

  const _ProfitLineItem({
    required this.date,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.buyingPrice,
    required this.profit,
    this.cashierName,
  });
}
