import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'config/routes/app_routes.dart';
import 'core/bloc/sync_status_cubit.dart';
import 'core/data/hive_database.dart';
import 'core/database/secondary_db.dart';
import 'core/service_locator.dart' as di;
import 'core/services/workmanager_sync.dart';
import 'core/services/firebase_options.dart';
import 'core/services/firebase_sync_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/sync_status.dart';
import 'core/theme/app_theme.dart';
import 'core/usecase/usecase.dart';
import 'core/utils/barcode_scanner_service.dart';
import 'core/utils/pin_encryption_service.dart';
import 'features/auth/domain/entities/user.dart';
import 'features/auth/domain/usecases/auth_usecases.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/customer/presentation/bloc/customer_bloc.dart';
import 'features/customer/presentation/bloc/customer_event.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_event.dart';
import 'features/supplier/presentation/bloc/supplier_bloc.dart';
import 'features/supplier/presentation/bloc/supplier_event.dart';
import 'features/employees/presentation/bloc/employee_bloc.dart';
import 'features/mpesa/presentation/bloc/mpesa_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  await SecondaryDb.database; // initialize secondary SQLite DB
  await di.init();
  await initializeWorkmanager(); // background sync every 15 min

  SyncService syncService = di.sl<SyncService>();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final fbSync = FirebaseSyncService();
    await fbSync.initialize();
    syncService = fbSync;
    di.sl.allowReassignment = true;
    di.sl.registerSingleton<SyncService>(fbSync);
    di.sl.allowReassignment = false;
    debugPrint('[FIREBASE] Initialized successfully');
  } catch (e) {
    debugPrint('[FIREBASE] Initialization skipped: $e');
    syncService.initialize();
  }

  await di.sl<PinEncryptionService>().initialize();
  BarcodeScannerService().initialize();
  await _seedDefaultAdmin();
  runApp(MyApp(syncService: syncService));
}

Future<void> _seedDefaultAdmin() async {
  final hasAdmin = await di.sl<HasAdminUseCase>()(NoParams());
  final exists = hasAdmin.getRight().toNullable() ?? false;
  if (!exists) {
    final id = const Uuid().v4();
    final result = await di.sl<SaveUserUseCase>()(User(
      id: id,
      name: 'Admin',
      pin: '1234',
      role: UserRole.admin,
    ));
    result.fold(
      (failure) => throw Exception('Failed to seed default admin: ${failure.message}'),
      (_) {},
    );
  }
}

class MyApp extends StatelessWidget {
  final SyncService syncService;
  const MyApp({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<SyncService>.value(
      value: syncService,
      child: MultiBlocProvider(
      providers: [
        BlocProvider<SyncStatusCubit>(
          create: (context) => SyncStatusCubit(syncService),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => di.sl<AuthBloc>()..add(CheckAuthEvent()),
        ),
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(const LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
        BlocProvider<CustomerBloc>(
            create: (context) => di.sl<CustomerBloc>()..add(const LoadCustomers())),
        BlocProvider<InventoryBloc>(
            create: (context) => di.sl<InventoryBloc>()..add(const LoadTransactions())),
        BlocProvider<SupplierBloc>(
            create: (context) => di.sl<SupplierBloc>()..add(const LoadSuppliers())),
        BlocProvider<EmployeeBloc>(
            create: (context) => di.sl<EmployeeBloc>()),
        BlocProvider<MpesaBloc>(
            create: (context) => di.sl<MpesaBloc>()),
      ],
      child: BlocListener<SyncStatusCubit, SyncStatus>(
        listenWhen: (prev, curr) =>
            curr == SyncStatus.connected ||
            curr == SyncStatus.error ||
            curr == SyncStatus.syncing,
        listener: (context, status) {
          final messenger = ScaffoldMessenger.of(context);
          if (status == SyncStatus.connected) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Cloud sync connected'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ));
          } else if (status == SyncStatus.error) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Cloud sync error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ));
          } else if (status == SyncStatus.syncing) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Syncing data to cloud...'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ));
          }
        },
        child: MaterialApp.router(
          title: 'POS MASHINANI',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
      ),
    );
  }
}
