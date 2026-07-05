import 'dart:async';

import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/usecase/usecase.dart';
import 'package:billing_app/features/reports/domain/entities/sale.dart';
import 'package:billing_app/features/reports/domain/usecases/sale_usecases.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ReportPeriod { today, week, month, all }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with WidgetsBindingObserver {
  ReportPeriod _period = ReportPeriod.week;
  List<Sale> _allSales = [];
  bool _loading = true;
  StreamSubscription? _salesSubscription;

  List<Sale> _filteredSales = [];
  double _totalSales = 0;
  int _orderCount = 0;
  double _avgOrder = 0;
  double _totalProfit = 0;
  Map<String, double> _salesByDay = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _salesSubscription = HiveDatabase.salesBox.watch().listen((_) => _loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _salesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final saleRepo = sl<GetAllSalesUseCase>();
      final result = await saleRepo(NoParams());
      result.fold(
        (_) => _allSales = [],
        (sales) => _allSales = sales,
      );
    } catch (_) {
    }
    _recomputeAggregates();
    if (mounted) setState(() => _loading = false);
  }

  void _recomputeAggregates() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.today:
        _filteredSales = _allSales.where((s) =>
            s.date.year == now.year &&
            s.date.month == now.month &&
            s.date.day == now.day).toList();
      case ReportPeriod.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        _filteredSales = _allSales.where((s) => s.date.isAfter(weekAgo)).toList();
      case ReportPeriod.month:
        _filteredSales = _allSales.where((s) =>
            s.date.year == now.year && s.date.month == now.month).toList();
      case ReportPeriod.all:
        _filteredSales = _allSales;
    }
    _orderCount = _filteredSales.length;
    _totalSales = _filteredSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    _avgOrder = _orderCount > 0 ? _totalSales / _orderCount : 0;
    _totalProfit = _filteredSales.fold(
        0.0,
        (sum, s) =>
            sum +
            s.items.fold(
                0.0, (itemSum, i) => itemSum + (i.unitPrice - i.buyingPrice) * i.quantity));
    final map = <String, double>{};
    for (final sale in _filteredSales) {
      final key = '${sale.date.year}-${sale.date.month.toString().padLeft(2, '0')}-${sale.date.day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + sale.grandTotal;
    }
    final sortedKeys = map.keys.toList()..sort();
    _salesByDay = <String, double>{};
    for (final k in sortedKeys) {
      _salesByDay[k] = map[k]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),
                    _buildMetricCards(),
                    const SizedBox(height: 24),
                    _buildChartSection(),
                    const SizedBox(height: 24),
                    _buildReportButtons(),
                    const SizedBox(height: 24),
                    if (_filteredSales.isNotEmpty) _buildRecentSalesTable(),
                  ],
                  ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = ReportPeriod.values;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: periods.map((p) {
          final selected = p == _period;
          final labels = {
            ReportPeriod.today: 'Today',
            ReportPeriod.week: 'Week',
            ReportPeriod.month: 'Month',
            ReportPeriod.all: 'All',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _period = p;
                _recomputeAggregates();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  labels[p]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.primaryColor : Colors.grey[500],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricCards() {
    final metrics = [
      ('Total Sales', AppConstants.formatPrice(_totalSales), Icons.trending_up,
          AppTheme.primaryColor),
      ('Orders', '$_orderCount', Icons.receipt_long, Colors.teal),
      ('Avg Order', AppConstants.formatPrice(_avgOrder), Icons.shopping_cart,
          Colors.orange),
      ('Profit', AppConstants.formatPrice(_totalProfit), Icons.monetization_on,
          Colors.green),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final (label, value, icon, color) = metrics[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                const Spacer(),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartSection() {
    final data = _salesByDay;
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('No sales data for this period',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    final entries = data.entries.toList();
    final maxVal = entries.fold(0.0, (m, e) => e.value > m ? e.value : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales Trend',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final label = entries[group.x].key;
                      final dateParts = label.split('-');
                      final short = dateParts.length == 3
                          ? '${dateParts[2]}/${dateParts[1]}'
                          : label;
                      return BarTooltipItem(
                        '$short\n${AppConstants.formatPrice(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, _) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          '${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = entries[idx].key.split('-');
                        final label = parts.length == 3
                            ? '${parts[2]}/${parts[1]}'
                            : entries[idx].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[400])),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[100]!,
                    strokeWidth: 1,
                  ),
                ),
                barGroups: entries.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value,
                        color: AppTheme.primaryColor,
                        width: _period == ReportPeriod.today ? 24 : 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButtons() {
    final reports = [
      ('Product Sales', Icons.inventory_2, 'Revenue by product',
          '/reports/product-sales'),
      ('Inventory', Icons.inventory, 'Current stock levels',
          '/reports/inventory'),
      ('Profit Analysis', Icons.trending_up, 'Margin by product',
          '/reports/profit-analysis'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reports',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 12),
        ...reports.map((r) {
          final (title, icon, subtitle, route) = r;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[100]!),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              title: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => context.push(route),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentSalesTable() {
    final recent = _filteredSales.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Transactions',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
          ),
          padding: const EdgeInsets.all(4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              columnSpacing: 20,
              headingRowColor:
                  WidgetStatePropertyAll(Colors.grey[50]),
              columns: const [
                DataColumn(label: Text('Date',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Items',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Payment',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Cashier',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold))),
              ],
              rows: recent.map((s) {
                final paymentType = s.cash > 0
                    ? 'Cash'
                    : s.mpesa > 0
                        ? 'M-Pesa'
                        : 'Card/Bank';
                return DataRow(cells: [
                  DataCell(Text(
                      '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')} ${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${s.items.length}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(AppConstants.formatPrice(s.grandTotal),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(paymentType,
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(s.cashierName ?? '-',
                      style: const TextStyle(fontSize: 12))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
      );
    }
  }
