import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/report_exporter.dart';
import '../../../../features/customer/presentation/pages/customer_management_page.dart';
import '../../../../features/employees/presentation/pages/employee_management_page.dart';
import '../../../../features/inventory/presentation/pages/inventory_movement_page.dart';
import '../../../../features/inventory/presentation/pages/purchase_receiving_page.dart';
import '../../../../features/product/data/models/product_model.dart';
import '../../../../features/product/presentation/pages/product_list_page.dart';
import '../../../../features/reports/data/models/sale_model.dart';
import '../../../../features/supplier/presentation/pages/supplier_management_page.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../bloc/auth_bloc.dart';

const _secDashboard = 0;
const _secTransactions = 1;
const _secInventory = 2;
const _secUsers = 3;
const _secAnalytics = 4;

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  List<SaleModel> _todaySales = [];
  List<SaleModel> _recentSales = [];
  List<SaleModel> _allSales = [];
  List<ProductModel> _allProducts = [];
  List<ProductModel> _lowStock = [];
  List<UserModel> _users = [];
  int _todayCount = 0;
  double _todayRevenue = 0;
  double _totalRevenue = 0;
  double _weekRevenue = 0;
  Timer? _timer;
  int _currentSection = _secDashboard;
  String? _txMerchantFilter;
  String? _txPaymentFilter;
  String? _invStatusFilter;
  String? _invCategoryFilter;
  String? _invAdminFilter;
  bool _showAllAnalytics = true;
  final _searchAnalyticsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchAnalyticsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final allSales = HiveDatabase.salesBox.values.toList();
    final weekStart = todayStart.subtract(const Duration(days: 7));
    final tdSales = allSales.where((s) => s.date.isAfter(todayStart) && s.date.isBefore(todayEnd)).toList();
    tdSales.sort((a, b) => b.date.compareTo(a.date));
    final weekSales = allSales.where((s) => s.date.isAfter(weekStart) && s.date.isBefore(todayEnd)).toList();

    final recent = List<SaleModel>.from(allSales)..sort((a, b) => b.date.compareTo(a.date));

    final allProducts = HiveDatabase.productBox.values.toList();
    final low = allProducts.where((p) => p.stock <= p.minStockLevel && p.minStockLevel > 0).toList();
    low.sort((a, b) => a.stock.compareTo(b.stock));

    final allUsers = await di.sl<GetAllUsersUseCase>()(NoParams());
    final users = allUsers.getRight().toNullable() ?? [];
    final userModels = users.map((u) => UserModel.fromEntity(u)).toList();

    if (mounted) {
      setState(() {
        _todaySales = tdSales;
        _allSales = allSales;
        _recentSales = recent.take(20).toList();
        _allProducts = allProducts;
        _lowStock = low;
        _users = userModels;
        _todayCount = tdSales.length;
        _todayRevenue = tdSales.fold<double>(0, (s, sale) => s + sale.grandTotal);
        _totalRevenue = allSales.fold<double>(0, (s, sale) => s + sale.grandTotal);
        _weekRevenue = weekSales.fold<double>(0, (s, sale) => s + sale.grandTotal);
      });
    }
  }

  void _exportTransactions() {
    final timeFmt = DateFormat('dd/MM HH:mm');
    final headers = ['#', 'ID', 'Cashier', 'Items', 'Total', 'Payment', 'Date/Time'];

    var data = _allSales.toList();
    if (_txMerchantFilter != null) {
      data = data.where((s) => (s.cashierName ?? 'Unknown') == _txMerchantFilter).toList();
    }
    if (_txPaymentFilter != null) {
      data = data.where((s) {
        switch (_txPaymentFilter) {
          case 'Cash': return s.cash > 0 && s.mpesa == 0 && s.card == 0 && s.bank == 0;
          case 'M-Pesa': return s.mpesa > 0;
          case 'Card': return s.card > 0;
          case 'Bank': return s.bank > 0;
          default: return true;
        }
      }).toList();
    }
    data.sort((a, b) => b.date.compareTo(a.date));

    final rows = data.asMap().entries.map((e) {
      final i = e.key + 1;
      final s = e.value;
      return [
        '$i',
        s.id.length > 8 ? s.id.substring(0, 8) : s.id,
        s.cashierName ?? '-',
        '${s.items.length}',
        AppConstants.formatPrice(s.grandTotal),
        s.mpesa > 0 ? 'M-Pesa' : s.card > 0 ? 'Card' : s.bank > 0 ? 'Bank' : 'Cash',
        timeFmt.format(s.date),
      ];
    }).toList();

    showExportDialog(
      context,
      title: 'Transactions',
      headers: headers,
      rows: rows,
    );
  }

  void _exportUsers() {
    final headers = ['Name', 'Role', 'Status', 'Active'];
    final rows = _users.map((u) => [
      u.name,
      u.isSuperAdmin ? 'Super Admin' : u.role == UserRole.admin ? 'Admin' : 'Cashier',
      !u.isActive ? 'Inactive' : !u.hasCompletedSetup ? 'Pending' : 'Active',
      u.isActive ? 'Yes' : 'No',
    ]).toList();

    showExportDialog(
      context,
      title: 'User Management',
      headers: headers,
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 900;

        return Scaffold(
          body: Row(
            children: [
              if (!isMobile)
                _Sidebar(
                  currentSection: _currentSection,
                  onSectionChanged: (v) => setState(() => _currentSection = v),
                  onLogout: () => context.read<AuthBloc>().add(LogoutEvent()),
                  onRefresh: _loadData,
                  collapsed: isTablet,
                ),
              Expanded(
                child: _buildContent(isMobile),
              ),
            ],
          ),
          bottomNavigationBar: isMobile ? _MobileBottomNav(
            currentSection: _currentSection,
            onSectionChanged: (v) => setState(() => _currentSection = v),
          ) : null,
        );
      },
    );
  }

  Widget _buildContent(bool isMobile) {
    final body = _buildSectionContent();
    final sections = [
      (_secDashboard, Icons.dashboard_rounded, 'Dashboard'),
      (_secTransactions, Icons.receipt_long_rounded, 'Transactions'),
      (_secInventory, Icons.inventory_2_rounded, 'Inventory'),
      (_secUsers, Icons.people_rounded, 'Users'),
      (_secAnalytics, Icons.analytics_rounded, 'Analytics'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForSection(_currentSection)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isMobile
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
        actions: [
          if (_currentSection == _secTransactions && _recentSales.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export transactions',
              onPressed: _exportTransactions,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: isMobile
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.05),
                        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.indigo),
                          ),
                          const SizedBox(width: 12),
                          const Text('Super Admin',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: sections.map((s) {
                          final active = _currentSection == s.$1;
                          return ListTile(
                            leading: Icon(s.$2, color: active ? Colors.indigo : Colors.grey[600]),
                            title: Text(s.$3,
                                style: TextStyle(
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                  color: active ? Colors.indigo : Colors.grey[700],
                                )),
                            selected: active,
                            selectedTileColor: Colors.indigo.withValues(alpha: 0.05),
                            onTap: () {
                              setState(() => _currentSection = s.$1);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.refresh_rounded, color: Colors.grey[600]),
                      title: Text('Refresh', style: TextStyle(color: Colors.grey[700])),
                      onTap: () {
                        Navigator.pop(context);
                        _loadData();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout_rounded, color: Colors.red[400]),
                      title: Text('Logout', style: TextStyle(color: Colors.red[400])),
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(LogoutEvent());
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: body,
      ),
    );
  }

  String _titleForSection(int section) {
    switch (section) {
      case _secDashboard:
        return 'Dashboard';
      case _secTransactions:
        return 'Transactions';
      case _secInventory:
        return 'Inventory';
      case _secUsers:
        return 'Users';
      case _secAnalytics:
        return 'Analytics';
      default:
        return '';
    }
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case _secDashboard:
        return _buildDashboard();
      case _secTransactions:
        return _buildTransactions();
      case _secInventory:
        return _buildInventory();
      case _secUsers:
        return _buildUsers();
      case _secAnalytics:
        return _buildAnalytics();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _KpiRow(
          todayCount: _todayCount,
          todayRevenue: _todayRevenue,
          lowStockCount: _lowStock.length,
          pendingUsers: _users.where((u) => u.isActive && !u.hasCompletedSetup).length,
        ),
        const SizedBox(height: 20),
        _RevenueChart(sales: _todaySales, allSales: HiveDatabase.salesBox.values.toList()),
      ],
    );
  }

  Widget _buildTransactions() {
    final currency = NumberFormat('#,##0', 'en_US');
    final merchantNames = _allSales
        .map((s) => s.cashierName ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();
    final paymentMethods = ['Cash', 'M-Pesa', 'Card', 'Bank'];

    var filtered = _allSales.toList();
    if (_txMerchantFilter != null) {
      filtered = filtered.where((s) => (s.cashierName ?? 'Unknown') == _txMerchantFilter).toList();
    }
    if (_txPaymentFilter != null) {
      filtered = filtered.where((s) {
        switch (_txPaymentFilter) {
          case 'Cash': return s.cash > 0 && s.mpesa == 0 && s.card == 0 && s.bank == 0;
          case 'M-Pesa': return s.mpesa > 0;
          case 'Card': return s.card > 0;
          case 'Bank': return s.bank > 0;
          default: return true;
        }
      }).toList();
    }
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.account_balance_wallet_rounded, 'Total Revenue', 'KSh ${currency.format(_totalRevenue)}', Colors.indigo)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.today_rounded, "Today's Revenue", 'KSh ${currency.format(_todayRevenue)}', Colors.green)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.date_range_rounded, 'Week Revenue', 'KSh ${currency.format(_weekRevenue)}', Colors.teal)),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: _txKpiCard(Icons.account_balance_wallet_rounded, 'Total Revenue', 'KSh ${currency.format(_totalRevenue)}', Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(child: _txKpiCard(Icons.today_rounded, "Today's Revenue", 'KSh ${currency.format(_todayRevenue)}', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _txKpiCard(Icons.date_range_rounded, 'Week Revenue', 'KSh ${currency.format(_weekRevenue)}', Colors.teal)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobileFilters = constraints.maxWidth < 600;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobileFilters ? 12 : 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: isMobileFilters
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _txMerchantFilter,
                                  isExpanded: true,
                                  hint: Text('All Merchants', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  items: [
                                    DropdownMenuItem<String>(value: null, child: Text('All Merchants', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                    ...merchantNames.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13)))),
                                  ],
                                  onChanged: (v) => setState(() => _txMerchantFilter = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 26),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _txPaymentFilter,
                                  isExpanded: true,
                                  hint: Text('All Payments', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  items: [
                                    DropdownMenuItem<String>(value: null, child: Text('All Payments', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                    ...paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))),
                                  ],
                                  onChanged: (v) => setState(() => _txPaymentFilter = v),
                                ),
                              ),
                            ),
                            if (_txMerchantFilter != null || _txPaymentFilter != null)
                              GestureDetector(
                                onTap: () => setState(() { _txMerchantFilter = null; _txPaymentFilter = null; }),
                                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                              ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _txMerchantFilter,
                              isExpanded: true,
                              hint: Text('All Merchants', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              items: [
                                DropdownMenuItem<String>(value: null, child: Text('All Merchants', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                ...merchantNames.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (v) => setState(() => _txMerchantFilter = v),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 24, color: Colors.grey[200]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _txPaymentFilter,
                              isExpanded: true,
                              hint: Text('All Payments', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              items: [
                                DropdownMenuItem<String>(value: null, child: Text('All Payments', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                ...paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (v) => setState(() => _txPaymentFilter = v),
                            ),
                          ),
                        ),
                        if (_txMerchantFilter != null || _txPaymentFilter != null)
                          GestureDetector(
                            onTap: () => setState(() { _txMerchantFilter = null; _txPaymentFilter = null; }),
                            child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                          ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 12),
        _TransactionsTable(sales: filtered),
      ],
    );
  }

  Widget _txKpiCard(IconData icon, String label, String value, Color color, {bool badge = false, VoidCallback? onTap}) {
    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badge ? color.withValues(alpha: 0.4) : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.isNotEmpty ? value : label, style: TextStyle(fontSize: 14, fontWeight: value.isNotEmpty ? FontWeight.bold : FontWeight.w500, color: color)),
                  if (value.isNotEmpty) Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
    return card;
  }

  Widget _buildInventory() {
    final currency = NumberFormat('#,##0', 'en_US');
    final lowStock = _allProducts.where((p) => p.stock <= p.minStockLevel && p.minStockLevel > 0).toList();
    final outOfStock = _allProducts.where((p) => p.stock == 0).toList();
    final totalValue = _allProducts.fold<double>(0, (s, p) => s + p.stock * p.buyingPrice);

    final categories = _allProducts
        .map((p) => p.category ?? 'General')
        .toSet()
        .toList()
      ..sort();
    final statusOptions = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];

    var filtered = _allProducts.toList();
    if (_invStatusFilter != null && _invStatusFilter != 'All') {
      switch (_invStatusFilter) {
        case 'Low Stock':
          filtered = filtered.where((p) => p.stock <= p.minStockLevel && p.minStockLevel > 0).toList();
        case 'Out of Stock':
          filtered = filtered.where((p) => p.stock == 0).toList();
        case 'In Stock':
          filtered = filtered.where((p) => p.stock > p.minStockLevel || p.minStockLevel == 0).toList();
      }
    }
    if (_invCategoryFilter != null) {
      filtered = filtered.where((p) => (p.category ?? 'General') == _invCategoryFilter).toList();
    }
    if (_invAdminFilter != null) {
      filtered = filtered.where((p) => p.assignedTo == _invAdminFilter).toList();
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));
    final adminNames = <String, String>{
      for (final u in HiveDatabase.usersBox.values) u.id: u.name,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.inventory_2_rounded, 'Total Products', '${_allProducts.length}', Colors.indigo)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.monetization_on_rounded, 'Stock Value', 'KSh ${currency.format(totalValue)}', Colors.green)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.warning_amber_rounded, 'Low Stock', '${lowStock.length}', Colors.red, badge: lowStock.isNotEmpty)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.lens_rounded, 'Out of Stock', '${outOfStock.length}', Colors.red[700]!, badge: outOfStock.isNotEmpty)),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.add_box_rounded, 'Purchase', '', Colors.teal, onTap: () => _pushPage('/purchase-receiving'))),
                  SizedBox(width: double.infinity, child: _txKpiCard(Icons.swap_vert_rounded, 'Movements', '', Colors.orange, onTap: () => _pushPage('/inventory-movement'))),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _txKpiCard(Icons.inventory_2_rounded, 'Total Products', '${_allProducts.length}', Colors.indigo)),
                    const SizedBox(width: 8),
                    Expanded(child: _txKpiCard(Icons.monetization_on_rounded, 'Stock Value', 'KSh ${currency.format(totalValue)}', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _txKpiCard(Icons.warning_amber_rounded, 'Low Stock', '${lowStock.length}', Colors.red, badge: lowStock.isNotEmpty)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _txKpiCard(Icons.lens_rounded, 'Out of Stock', '${outOfStock.length}', Colors.red[700]!, badge: outOfStock.isNotEmpty)),
                    const SizedBox(width: 8),
                    Expanded(child: _txKpiCard(Icons.add_box_rounded, 'Purchase', '', Colors.teal, onTap: () => _pushPage('/purchase-receiving'))),
                    const SizedBox(width: 8),
                    Expanded(child: _txKpiCard(Icons.swap_vert_rounded, 'Movements', '', Colors.orange, onTap: () => _pushPage('/inventory-movement'))),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobileFilters = constraints.maxWidth < 600;
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobileFilters ? 10 : 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: isMobileFilters
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _invStatusFilter,
                                      isExpanded: true,
                                      hint: Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      items: statusOptions.map((s) => DropdownMenuItem(value: s == 'All' ? null : s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                      onChanged: (v) => setState(() => _invStatusFilter = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(width: 26),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _invCategoryFilter,
                                      isExpanded: true,
                                      hint: Text('Category', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      items: [
                                        DropdownMenuItem<String>(value: null, child: Text('All Categories', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))),
                                      ],
                                      onChanged: (v) => setState(() => _invCategoryFilter = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _invStatusFilter,
                                  isExpanded: true,
                                  hint: Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  items: statusOptions.map((s) => DropdownMenuItem(value: s == 'All' ? null : s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (v) => setState(() => _invStatusFilter = v),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 24, color: Colors.grey[200]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _invCategoryFilter,
                                  isExpanded: true,
                                  hint: Text('Category', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  items: [
                                    DropdownMenuItem<String>(value: null, child: Text('All Categories', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                    ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))),
                                  ],
                                  onChanged: (v) => setState(() => _invCategoryFilter = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _invAdminFilter,
                            isExpanded: true,
                            hint: Text('All Admins', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            items: [
                              DropdownMenuItem<String>(value: null, child: Text('All Admins', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                              for (final u in HiveDatabase.usersBox.values)
                                if (u.role.name == 'admin' || u.role.name == 'superAdmin')
                                  DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _invAdminFilter = v),
                          ),
                        ),
                      ),
                      if (_invAdminFilter != null)
                        GestureDetector(
                          onTap: () => setState(() => _invAdminFilter = null),
                          child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _InventoryTable(products: filtered, currency: currency, adminNames: adminNames),
      ],
    );
  }

  Widget _buildUsers() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'User Management', onExport: _exportUsers),
        const SizedBox(height: 8),
        if (_users.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text('No users found', style: TextStyle(color: Colors.grey[500]))),
          )
        else
          ..._users.map((u) => _UserCard(
                user: u,
                onToggle: () => _toggleActive(u),
                onResetPin: () => _resetPin(u),
              )),
      ],
    );
  }

  Widget _buildAnalytics() {
    final currency = NumberFormat('#,##0', 'en_US');
    final f2 = NumberFormat('#,##0.00', 'en_US');

    final allSales = HiveDatabase.salesBox.values.toList();
    List<SaleModel> sales;
    if (_showAllAnalytics) {
      sales = allSales;
    } else {
      final q = _searchAnalyticsCtrl.text.trim().toLowerCase();
      sales = q.isEmpty ? allSales : allSales.where((s) => (s.cashierName ?? '').toLowerCase().contains(q)).toList();
    }

    double cash = 0, mpesa = 0, card = 0, bank = 0;
    for (final s in sales) {
      cash += s.cash;
      mpesa += s.mpesa;
      card += s.card;
      bank += s.bank;
    }
    final total = cash + mpesa + card + bank;
    final avgSale = sales.isEmpty ? 0.0 : total / sales.length;

    final prodQty = <String, int>{};
    for (final s in sales) {
      for (final item in s.items) {
        prodQty[item.productName] = (prodQty[item.productName] ?? 0) + item.quantity;
      }
    }
    final topProds = prodQty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topProds.take(5).toList();
    final maxProd = top5.isEmpty ? 1 : top5.first.value;

    final merRev = <String, double>{};
    final merTx = <String, int>{};
    for (final s in sales) {
      final n = s.cashierName ?? 'Unknown';
      merRev[n] = (merRev[n] ?? 0) + s.grandTotal;
      merTx[n] = (merTx[n] ?? 0) + 1;
    }
    final sorted = merRev.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxMer = sorted.isEmpty ? 1.0 : sorted.first.value;
    final merchantCount = sorted.length;

    Widget toggleBtn(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : Colors.grey[600])),
        ),
      );
    }

    Widget kpiCard(String label, String value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))),
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    List<PieChartSectionData> paymentSections(double c, double m, double cd, double b, double t) {
      if (t == 0) return [];
      final style = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white);
      final result = <PieChartSectionData>[];
      if (c > 0) result.add(PieChartSectionData(value: c, color: Colors.green, title: '${(c / t * 100).toStringAsFixed(0)}%', titleStyle: style, radius: 36));
      if (m > 0) result.add(PieChartSectionData(value: m, color: Colors.cyan, title: '${(m / t * 100).toStringAsFixed(0)}%', titleStyle: style, radius: 36));
      if (cd > 0) result.add(PieChartSectionData(value: cd, color: Colors.indigo, title: '${(cd / t * 100).toStringAsFixed(0)}%', titleStyle: style, radius: 36));
      if (b > 0) result.add(PieChartSectionData(value: b, color: Colors.orange, title: '${(b / t * 100).toStringAsFixed(0)}%', titleStyle: style, radius: 36));
      if (result.isEmpty) result.add(PieChartSectionData(value: t, color: Colors.grey, title: '100%', titleStyle: style, radius: 36));
      return result;
    }

    Widget buildPaymentPie() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Methods', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: total == 0
                  ? Center(child: Text('No data', style: TextStyle(color: Colors.grey[400], fontSize: 12)))
                  : PieChart(PieChartData(sections: paymentSections(cash, mpesa, card, bank, total), centerSpaceRadius: 26, sectionsSpace: 2)),
            ),
            const SizedBox(height: 10),
            ...[
              ('Cash', cash, Colors.green),
              ('M-Pesa', mpesa, Colors.cyan),
              ('Card', card, Colors.indigo),
              ('Bank', bank, Colors.orange),
            ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: e.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(e.$1, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const Spacer(),
                      Text(total == 0 ? '0%' : '${(e.$2 / total * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    Widget buildTopProducts() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Products', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: top5.isEmpty
                  ? Center(child: Text('No data', style: TextStyle(color: Colors.grey[400], fontSize: 12)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxProd.toDouble(),
                        barGroups: top5.asMap().entries.map((e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value.toDouble(),
                              color: Colors.indigo.withValues(alpha: 0.5 + 0.1 * (top5.length - e.key)),
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        )).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, m) {
                                final i = v.toInt();
                                if (i < 0 || i >= top5.length) return const SizedBox();
                                final name = top5[i].key;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(name.length > 7 ? '${name.substring(0, 7)}..' : name, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (g, i, r, j) => BarTooltipItem('${top5[g.x].value} pcs', TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                    ),
            ),
            ...top5.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: TextStyle(fontSize: 10, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                      Text('${e.value} pcs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    Widget buildMerchantChart() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant Revenue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No sales data yet', style: TextStyle(color: Colors.grey[400]))),
              )
            else
              ...sorted.map((e) {
                final ratio = e.value / maxMer;
                final rank = sorted.indexOf(e) + 1;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 22, child: Text('$rank', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600))),
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text(e.key[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 4,
                                backgroundColor: Colors.indigo.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation(rank == 1 ? Colors.indigo : Colors.indigo.withValues(alpha: 0.4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('KSh ${currency.format(e.value.toInt())}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    }

    Widget buildMerchantDetail() {
      if (_showAllAnalytics || _searchAnalyticsCtrl.text.trim().isEmpty) return const SizedBox();
      double c = 0, m = 0, cd = 0, b = 0;
      for (final s in sales) {
        c += s.cash;
        m += s.mpesa;
        cd += s.card;
        b += s.bank;
      }
      final t = c + m + cd + b;
      final merchantName = _searchAnalyticsCtrl.text.trim();
      final exact = sales.where((s) => (s.cashierName ?? '').toLowerCase() == merchantName.toLowerCase()).toList();
      final displayName = exact.isNotEmpty ? exact.first.cashierName! : merchantName;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigo.withValues(alpha: 0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('${sales.length} transactions', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('KSh ${currency.format(t.toInt())}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Text('Avg: KSh ${currency.format(sales.isEmpty ? 0 : (t / sales.length).toInt())}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...[
              ('Cash', c, Colors.green),
              ('M-Pesa', m, Colors.cyan),
              ('Card', cd, Colors.indigo),
              ('Bank', b, Colors.orange),
            ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e.$1, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const Spacer(),
                          Text('KSh ${f2.format(e.$2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: t == 0 ? 0 : e.$2 / t,
                          minHeight: 4,
                          backgroundColor: e.$3.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(e.$3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Spacer(),
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  toggleBtn('All', _showAllAnalytics, () => setState(() => _showAllAnalytics = true)),
                  toggleBtn('Admin', !_showAllAnalytics, () => setState(() => _showAllAnalytics = false)),
                ],
              ),
            ),
          ],
        ),
        if (!_showAllAnalytics) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchAnalyticsCtrl,
            decoration: InputDecoration(
              hintText: 'Search admin name...',
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
              suffixIcon: _searchAnalyticsCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: Colors.grey[400]),
                      onPressed: () { _searchAnalyticsCtrl.clear(); setState(() {}); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              final cardWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(width: cardWidth, child: kpiCard('Revenue', 'KSh ${currency.format(total.toInt())}', Icons.account_balance_wallet_rounded, Colors.indigo)),
                  SizedBox(width: cardWidth, child: kpiCard('Transactions', '${sales.length}', Icons.receipt_long_rounded, Colors.teal)),
                  SizedBox(width: cardWidth, child: kpiCard('Avg / Sale', 'KSh ${currency.format(avgSale.toInt())}', Icons.trending_up_rounded, Colors.orange)),
                  SizedBox(width: cardWidth, child: kpiCard('Merchants', '$merchantCount', Icons.people_rounded, Colors.purple)),
                ],
              );
            }
            return Column(
              children: [
                Row(children: [
                  Expanded(child: kpiCard('Revenue', 'KSh ${currency.format(total.toInt())}', Icons.account_balance_wallet_rounded, Colors.indigo)),
                  const SizedBox(width: 8),
                  Expanded(child: kpiCard('Transactions', '${sales.length}', Icons.receipt_long_rounded, Colors.teal)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: kpiCard('Avg / Sale', 'KSh ${currency.format(avgSale.toInt())}', Icons.trending_up_rounded, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: kpiCard('Merchants', '$merchantCount', Icons.people_rounded, Colors.purple)),
                ]),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 600;
            if (isStacked) {
              return Column(
                children: [
                  buildPaymentPie(),
                  const SizedBox(height: 8),
                  buildTopProducts(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildPaymentPie()),
                const SizedBox(width: 8),
                Expanded(child: buildTopProducts()),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        buildMerchantChart(),
        const SizedBox(height: 16),
        buildMerchantDetail(),
      ],
    );
  }

  void _pushPage(String route) {
    Widget page;
    switch (route) {
      case '/products':
        page = const ProductListPage();
      case '/customers':
        page = const CustomerManagementPage();
      case '/suppliers':
        page = const SupplierManagementPage();
      case '/users':
        page = const EmployeeManagementPage();
      case '/purchase-receiving':
        page = const PurchaseReceivingPage();
      case '/inventory-movement':
        page = const InventoryMovementPage();
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _toggleActive(UserModel user) async {
    final updated = user.copyWith(
      isActive: !user.isActive,
    );
    await di.sl<UpdateUserUseCase>()(updated);
    _loadData();
  }

  Future<void> _resetPin(UserModel user) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        String? selectedAction;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (selectedAction == 'custom') {
              return AlertDialog(
                title: const Text('Set Custom PIN'),
                content: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'New 4-digit PIN',
                    hintText: 'Enter new PIN',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      ctrl.clear();
                      setDialogState(() => selectedAction = null);
                    },
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Set PIN'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Reset PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose how to reset the PIN for this user:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'default'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to default (1234)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setDialogState(() => selectedAction = 'custom'),
                      icon: const Icon(Icons.edit),
                      label: const Text('Set custom PIN'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result == 'default') {
      final updated = user.copyWith(
        pin: '1234',
        previousPin: user.pin,
        hasCompletedSetup: false,
        isPinReset: true,
        isActive: true,
      );
      await di.sl<UpdateUserUseCase>()(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} PIN reset to default (1234)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (result.length == 4) {
      final updated = user.copyWith(
        pin: result,
        previousPin: user.pin,
        hasCompletedSetup: false,
        isPinReset: true,
        isActive: true,
      );
      await di.sl<UpdateUserUseCase>()(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} PIN reset')),
        );
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  final int currentSection;
  final ValueChanged<int> onSectionChanged;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final bool collapsed;

  const _Sidebar({
    required this.currentSection,
    required this.onSectionChanged,
    required this.onLogout,
    required this.onRefresh,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      (_secDashboard, Icons.dashboard_rounded, 'Dashboard'),
      (_secTransactions, Icons.receipt_long_rounded, 'Transactions'),
      (_secInventory, Icons.inventory_2_rounded, 'Inventory'),
      (_secUsers, Icons.people_rounded, 'Users'),
      (_secAnalytics, Icons.analytics_rounded, 'Analytics'),
    ];

    return Container(
      width: collapsed ? 64 : 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: collapsed
                ? const EdgeInsets.symmetric(vertical: 14)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            ),
            child: collapsed
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Colors.indigo),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Colors.indigo),
                      ),
                      const SizedBox(width: 10),
                      const Text('Super Admin',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: sections.map((s) {
                final isActive = currentSection == s.$1;
                return Padding(
                  padding: collapsed
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSectionChanged(s.$1),
                      child: Tooltip(
                        message: collapsed ? s.$3 : '',
                        preferBelow: false,
                        child: Container(
                          padding: collapsed
                              ? const EdgeInsets.symmetric(vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.indigo.withValues(alpha: 0.08) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: collapsed
                              ? Center(
                                  child: Icon(s.$2, size: 20, color: isActive ? Colors.indigo : Colors.grey[600]),
                                )
                              : Row(
                                  children: [
                                    Icon(s.$2, size: 20, color: isActive ? Colors.indigo : Colors.grey[600]),
                                    const SizedBox(width: 12),
                                    Text(s.$3,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                          color: isActive ? Colors.indigo : Colors.grey[700],
                                        )),
                                    if (isActive) ...[
                                      const Spacer(),
                                      Container(
                                        width: 6, height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.indigo,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: collapsed
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onRefresh,
                      child: Tooltip(
                        message: collapsed ? 'Refresh' : '',
                        preferBelow: false,
                        child: Container(
                          padding: collapsed
                              ? const EdgeInsets.symmetric(vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: collapsed
                              ? Center(child: Icon(Icons.refresh_rounded, size: 20, color: Colors.grey[600]))
                              : Row(
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 20, color: Colors.grey[600]),
                                    const SizedBox(width: 12),
                                    Text('Refresh', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: collapsed
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onLogout,
                      child: Tooltip(
                        message: collapsed ? 'Logout' : '',
                        preferBelow: false,
                        child: Container(
                          padding: collapsed
                              ? const EdgeInsets.symmetric(vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: collapsed
                              ? Center(child: Icon(Icons.logout_rounded, size: 20, color: Colors.red[400]))
                              : Row(
                                  children: [
                                    Icon(Icons.logout_rounded, size: 20, color: Colors.red[400]),
                                    const SizedBox(width: 12),
                                    Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red[400])),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final int currentSection;
  final ValueChanged<int> onSectionChanged;

  const _MobileBottomNav({
    required this.currentSection,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _navItem(Icons.dashboard_rounded, 'Dashboard', _secDashboard),
              _navItem(Icons.receipt_long_rounded, 'Transactions', _secTransactions),
              _navItem(Icons.inventory_2_rounded, 'Inventory', _secInventory),
              _navItem(Icons.people_rounded, 'Users', _secUsers),
              _navItem(Icons.analytics_rounded, 'Analytics', _secAnalytics),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int section) {
    final isActive = currentSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSectionChanged(section),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: isActive ? Colors.indigo : Colors.grey[500]),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.indigo : Colors.grey[500],
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onExport;

  const _SectionHeader({required this.title, this.onExport});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const Spacer(),
        if (onExport != null)
          TextButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int todayCount;
  final double todayRevenue;
  final int lowStockCount;
  final int pendingUsers;

  const _KpiRow({
    required this.todayCount,
    required this.todayRevenue,
    required this.lowStockCount,
    required this.pendingUsers,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'en_US');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 500 ? (width - 8) / 2 : (width - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpiCard(context, Icons.today, 'Sales', '$todayCount', Colors.indigo, width: cardWidth),
            _kpiCard(context, Icons.monetization_on, 'Revenue', 'KSh ${currency.format(todayRevenue)}', Colors.green, width: cardWidth),
            _kpiCard(context, Icons.warning_amber, 'Low Stock', '$lowStockCount', Colors.red, width: cardWidth, badge: lowStockCount > 0),
            _kpiCard(context, Icons.person_outline, 'Pending', '$pendingUsers', Colors.orange, width: cardWidth, badge: pendingUsers > 0),
          ],
        );
      },
    );
  }

  Widget _kpiCard(BuildContext context, IconData icon, String label, String value, Color color, {double? width, bool badge = false}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badge ? color.withValues(alpha: 0.4) : Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                ),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );

    return SizedBox(width: width, child: card);
  }
}

class _RevenueChart extends StatefulWidget {
  final List<SaleModel> sales;
  final List<SaleModel> allSales;

  const _RevenueChart({required this.sales, required this.allSales});

  @override
  State<_RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<_RevenueChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));
    final dayLabels = days.map((d) => DateFormat('E').format(d).substring(0, 3)).toList();

    final dailyTotals = days.map((day) {
      final end = day.add(const Duration(days: 1));
      return widget.allSales
          .where((s) => s.date.isAfter(day) && s.date.isBefore(end))
          .fold<double>(0, (sum, s) => sum + s.grandTotal);
    }).toList();

    final maxVal = dailyTotals.reduce((a, b) => a > b ? a : b);
    final currency = NumberFormat('#,##0', 'en_US');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('7-Day Revenue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ],
          ),
          const SizedBox(height: 20),
          if (maxVal == 0)
            SizedBox(
              height: 160,
              child: Center(child: Text('No revenue data yet', style: TextStyle(color: Colors.grey[500]))),
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.3,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${dayLabels[group.x.toInt()]}\nKSh ${currency.format(rod.toY)}',
                          TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                    touchCallback: (event, response) {
                      if (response?.spot != null && event.isInterestedForInteractions) {
                        setState(() => _selectedIndex = response!.spot!.touchedBarGroupIndex);
                      } else {
                        setState(() => _selectedIndex = null);
                      }
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            'KSh ${value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toInt().toString()}',
                            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= dayLabels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(dayLabels[idx],
                                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[100]!,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) {
                    final isSelected = _selectedIndex == i;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: dailyTotals[i],
                          color: isSelected ? Colors.indigo[700]! : Colors.indigo[300]!,
                          width: isSelected ? 20 : 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  final List<SaleModel> sales;

  const _TransactionsTable({required this.sales});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final currency = NumberFormat('#,##0', 'en_US');

    if (sales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey[500]))),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            children: sales.asMap().entries.map((entry) {
              final s = entry.value;
              final payment = s.mpesa > 0 ? 'M-Pesa' : s.card > 0 ? 'Card' : s.bank > 0 ? 'Bank' : 'Cash';
              final payColor = s.mpesa > 0 ? Colors.orange : s.card > 0 ? Colors.blue : s.bank > 0 ? Colors.purple : Colors.green;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('#${entry.key + 1}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        Text(s.id.length > 8 ? s.id.substring(0, 8) : s.id,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.cashierName ?? '-',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('KSh ${currency.format(s.grandTotal)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${s.items.length} items',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: payColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(payment,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: payColor)),
                        ),
                        const Spacer(),
                        Text(timeFmt.format(s.date),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columnSpacing: 20,
                headingRowColor: WidgetStatePropertyAll(Colors.grey[50]),
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cashier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: sales.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final s = entry.value;
                  final payment = s.mpesa > 0 ? 'M-Pesa' : s.card > 0 ? 'Card' : s.bank > 0 ? 'Bank' : 'Cash';
                  final payColor = s.mpesa > 0 ? Colors.orange : s.card > 0 ? Colors.blue : s.bank > 0 ? Colors.purple : Colors.green;
                  return DataRow(cells: [
                    DataCell(Text('$i', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    DataCell(Text(s.id.length > 8 ? s.id.substring(0, 8) : s.id,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                    DataCell(Text(s.cashierName ?? '-', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${s.items.length}', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('KSh ${currency.format(s.grandTotal)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: payColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(payment,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: payColor)),
                    )),
                    DataCell(Text(timeFmt.format(s.date), style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InventoryTable extends StatelessWidget {
  final List<ProductModel> products;
  final NumberFormat currency;
  final Map<String, String> adminNames;

  const _InventoryTable({required this.products, required this.currency, this.adminNames = const {}});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text('No products found', style: TextStyle(color: Colors.grey[500]))),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            children: products.asMap().entries.map((entry) {
              final p = entry.value;
              final isLow = p.stock <= p.minStockLevel && p.minStockLevel > 0;
              final isOut = p.stock == 0;
              String statusLabel;
              Color statusColor;
              if (isOut) {
                statusLabel = 'Out';
                statusColor = Colors.red;
              } else if (isLow) {
                statusLabel = 'Low';
                statusColor = Colors.orange;
              } else {
                statusLabel = 'OK';
                statusColor = Colors.green;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Category: ${p.category ?? '-'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const Spacer(),
                        Text('Stock: ${p.stock}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOut ? Colors.red : isLow ? Colors.orange : Colors.grey[800],
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Buy: KSh ${currency.format(p.buyingPrice)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Text('Sell: KSh ${currency.format(p.price)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (p.assignedTo != null && adminNames.containsKey(p.assignedTo))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Assigned: ${adminNames[p.assignedTo]}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columnSpacing: 20,
                headingRowColor: WidgetStatePropertyAll(Colors.grey[50]),
                columns: [
                  const DataColumn(label: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Min', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Buying', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Selling', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Assigned', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: products.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final p = entry.value;
                  final isLow = p.stock <= p.minStockLevel && p.minStockLevel > 0;
                  final isOut = p.stock == 0;
                  String statusLabel;
                  Color statusColor;
                  if (isOut) {
                    statusLabel = 'Out';
                    statusColor = Colors.red;
                  } else if (isLow) {
                    statusLabel = 'Low';
                    statusColor = Colors.orange;
                  } else {
                    statusLabel = 'OK';
                    statusColor = Colors.green;
                  }
                  return DataRow(cells: [
                    DataCell(Text('$i', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    DataCell(Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                    DataCell(Text(p.category ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                    DataCell(Text('${p.stock}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOut ? Colors.red : isLow ? Colors.orange : Colors.grey[800]))),
                    DataCell(Text('${p.minStockLevel}', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    DataCell(Text('KSh ${currency.format(p.buyingPrice)}', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                    DataCell(Text('KSh ${currency.format(p.price)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                    )),
                    DataCell(
                      p.assignedTo != null && adminNames.containsKey(p.assignedTo)
                          ? Text(adminNames[p.assignedTo]!, style: TextStyle(fontSize: 10, color: Colors.grey[500]))
                          : Text('-', style: TextStyle(fontSize: 10, color: Colors.grey[300])),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}



class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onResetPin;

  const _UserCard({required this.user, required this.onToggle, required this.onResetPin});

  @override
  Widget build(BuildContext context) {
    final color = user.isSuperAdmin
        ? Colors.red
        : user.role == UserRole.admin
            ? Colors.purple
            : Colors.teal;
    final roleLabel = user.isSuperAdmin
        ? 'Super Admin'
        : user.role == UserRole.admin
            ? 'Admin'
            : 'Cashier';

    String statusLabel;
    Color statusColor;
    if (!user.isActive) {
      statusLabel = 'Inactive';
      statusColor = Colors.red;
    } else if (!user.hasCompletedSetup) {
      statusLabel = 'Pending';
      statusColor = Colors.orange;
    } else {
      statusLabel = 'Active';
      statusColor = Colors.green;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !user.isActive
                  ? Colors.red[200]!
                  : !user.hasCompletedSetup
                      ? Colors.orange[200]!
                      : Colors.grey[200]!,
            ),
          ),
          child: isMobile
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Text(user.name[0].toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration: user.isActive ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('$roleLabel',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(statusLabel,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onResetPin,
                            icon: const Icon(Icons.lock_reset, size: 16),
                            label: const Text('Reset PIN', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                          const SizedBox(width: 8),
          Switch(
            value: user.isActive,
            onChanged: user.isSuperAdmin ? null : (_) => onToggle(),
            activeTrackColor: Colors.green[200],
            activeThumbColor: Colors.green,
          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(user.name[0].toUpperCase(),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: user.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text('$roleLabel · PIN: ****',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.lock_reset, size: 18),
                        onPressed: onResetPin,
                        tooltip: 'Reset PIN',
                        color: Colors.orange,
                      ),
                      Switch(
                        value: user.isActive,
                        onChanged: user.isSuperAdmin ? null : (_) => onToggle(),
                        activeTrackColor: Colors.green[200],
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
