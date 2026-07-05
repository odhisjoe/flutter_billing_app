import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/admin_dashboard_page.dart';
import '../../features/auth/presentation/pages/super_admin_dashboard.dart';
import '../../features/auth/presentation/pages/operations_pin_page.dart';
import '../../features/auth/presentation/pages/pin_login_page.dart';
import '../../features/auth/presentation/pages/set_pin_page.dart';
import '../../features/auth/presentation/pages/link_to_shop_page.dart';
import '../../features/admin/presentation/pages/link_device_page.dart';
import '../../features/employees/presentation/pages/employee_management_page.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reports/presentation/pages/product_sales_report_page.dart';
import '../../features/reports/presentation/pages/inventory_report_page.dart';
import '../../features/reports/presentation/pages/profit_analysis_report_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/inventory/presentation/pages/reorder_alerts_page.dart';
import '../../features/inventory/presentation/pages/purchase_receiving_page.dart';
import '../../features/inventory/presentation/pages/inventory_movement_page.dart';
import '../../features/customer/presentation/pages/customer_management_page.dart';
import '../../features/customer/presentation/pages/add_customer_page.dart';
import '../../features/customer/presentation/pages/customer_detail_page.dart';
import '../../features/supplier/presentation/pages/supplier_management_page.dart';
import '../../features/supplier/presentation/pages/add_supplier_page.dart';
import '../../features/supplier/domain/entities/supplier.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/mpesa/presentation/pages/mpesa_config_page.dart';
import '../../features/auth/presentation/pages/download_apk_page.dart';
import '../../features/settings/presentation/pages/download_windows_page.dart';

final _adminRoutes = [
  '/products', '/products/add', '/products/edit',
  '/customers', '/customers/add', '/customers/detail',
  '/suppliers', '/suppliers/add',
  '/reports', '/reports/product-sales', '/reports/inventory', '/reports/profit-analysis',
  '/shop',
  '/purchase-receiving',
  '/inventory-movement',
  '/reorder-alerts',
  '/admin',
  '/users',
  '/settings',
];

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final location = state.uri.toString();

    if (authState.status == AuthStatus.initial) return null;

    final loggedIn = authState.status == AuthStatus.authenticated;
    final isLoginPage = location == '/login';

    if (!loggedIn && !isLoginPage) {
      final isPublicRoute = location == '/super-admin' || location == '/operations-pin' || location == '/download' || location == '/download-windows' || location == '/link-to-shop';
      if (!isPublicRoute) return '/login';
    }
    if (loggedIn && isLoginPage) {
      if (authState.user!.isSuperAdmin) return '/super-admin';
      return authState.user!.role == UserRole.admin ? '/admin' : '/';
    }

    if (loggedIn && (authState.needsPinChange ?? false)) {
      if (location != '/set-pin') return '/set-pin';
      return null;
    }

    if (loggedIn && authState.user!.role == UserRole.cashier) {
      final isAdminRoute = _adminRoutes.any((r) => location.startsWith(r));
      if (isAdminRoute) return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/download',
      builder: (context, state) => const DownloadApkPage(),
    ),
    GoRoute(
      path: '/download-windows',
      builder: (context, state) => const DownloadWindowsPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const PinLoginPage(),
    ),
    GoRoute(
      path: '/link-to-shop',
      builder: (context, state) => const LinkToShopPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => ScannerPage(
            continuousScan: state.extra is Map && (state.extra as Map)['continuous'] == true,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
      routes: [
        GoRoute(
          path: 'link-device',
          builder: (context, state) => const LinkDevicePage(),
        ),
      ],
    ),
    GoRoute(
      path: '/set-pin',
      builder: (context, state) => const SetPinPage(),
    ),
    GoRoute(
      path: '/super-admin',
      builder: (context, state) => const SuperAdminDashboard(),
    ),
    GoRoute(
      path: '/operations-pin',
      builder: (context, state) => const OperationsPinPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        GoRoute(
          path: 'mpesa',
          builder: (context, state) => const MpesaConfigPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsPage(),
      routes: [
        GoRoute(
          path: 'product-sales',
          builder: (context, state) => const ProductSalesReportPage(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const InventoryReportPage(),
        ),
        GoRoute(
          path: 'profit-analysis',
          builder: (context, state) => const ProfitAnalysisReportPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
    GoRoute(
      path: '/reorder-alerts',
      builder: (context, state) => const ReorderAlertsPage(),
    ),
    GoRoute(
      path: '/purchase-receiving',
      builder: (context, state) => const PurchaseReceivingPage(),
    ),
    GoRoute(
      path: '/inventory-movement',
      builder: (context, state) => const InventoryMovementPage(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerManagementPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddCustomerPage(),
        ),
        GoRoute(
          path: 'detail/:id',
          builder: (context, state) {
            final customerId = state.pathParameters['id'] ?? '';
            return CustomerDetailPage(customerId: customerId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/suppliers',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SupplierManagementPage(),
      ),
      routes: [
        GoRoute(
          path: 'add',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: AddSupplierPage(supplier: state.extra as Supplier?),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const EmployeeManagementPage(),
    ),
  ],
);
