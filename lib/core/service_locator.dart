import 'package:get_it/get_it.dart';
import 'utils/pin_encryption_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/employees/presentation/bloc/employee_bloc.dart';
import '../../features/product/data/repositories/product_repository_impl.dart';
import '../../features/product/domain/repositories/product_repository.dart';
import '../../features/product/domain/usecases/product_usecases.dart';
import '../../features/product/presentation/bloc/product_bloc.dart';
import '../../features/reports/data/repositories/sale_repository_impl.dart';
import '../../features/reports/domain/repositories/sale_repository.dart';
import '../../features/reports/domain/usecases/sale_usecases.dart';
import '../../features/shop/data/repositories/shop_repository_impl.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/domain/usecases/shop_usecases.dart';
import '../../features/shop/presentation/bloc/shop_bloc.dart';
import '../../features/settings/data/repositories/printer_repository_impl.dart';
import '../../features/settings/domain/repositories/printer_repository.dart';
import '../../features/settings/presentation/bloc/printer_bloc.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/usecases/inventory_usecases.dart';
import '../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../features/customer/data/repositories/customer_repository_impl.dart';
import '../../features/customer/domain/repositories/customer_repository.dart';
import '../../features/customer/domain/usecases/customer_usecases.dart';
import '../../features/customer/presentation/bloc/customer_bloc.dart';
import '../../features/supplier/data/repositories/supplier_repository_impl.dart';
import '../../features/supplier/domain/repositories/supplier_repository.dart';
import '../../features/supplier/domain/usecases/supplier_usecases.dart';
import '../../features/supplier/presentation/bloc/supplier_bloc.dart';
import '../../features/mpesa/data/mpesa_repository_impl.dart';
import '../../features/mpesa/presentation/bloc/mpesa_bloc.dart';
import 'services/noop_sync_service.dart';
import 'services/sync_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core Services
  sl.registerLazySingleton<SyncService>(() => NoopSyncService());
  sl.registerLazySingleton<PinEncryptionService>(() => PinEncryptionService());

  // Features - Auth
  // Bloc
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      authRepository: sl(),
      encryptionService: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(encryptionService: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => HasAdminUseCase(sl()));
  sl.registerLazySingleton(() => SaveUserUseCase(sl()));
  sl.registerLazySingleton(() => GetAllUsersUseCase(sl()));
  sl.registerLazySingleton(() => DeleteUserUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserUseCase(sl()));

  // Features - Product
  // Bloc
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  sl.registerFactory(
    () => InventoryBloc(
      addTransactionUseCase: sl(),
      getAllTransactionsUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => CustomerBloc(
      getAllCustomersUseCase: sl(),
      addCustomerUseCase: sl(),
      updateCustomerUseCase: sl(),
      deleteCustomerUseCase: sl(),
      searchCustomersUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );

  // Features - Shop
  // Use cases
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(),
  );

  // Features - Settings / Printer
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );

  // Features - Reports / Sales
  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(),
  );
  sl.registerLazySingleton(() => SaveSaleUseCase(sl()));
  sl.registerLazySingleton(() => GetSalesByDateRangeUseCase(sl()));
  sl.registerLazySingleton(() => GetAllSalesUseCase(sl()));

  // Features - Inventory
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(),
  );
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAllTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsByProductUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsByTypeUseCase(sl()));

  // Features - Customer
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(),
  );
  sl.registerLazySingleton(() => AddCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomerByPhoneUseCase(sl()));
  sl.registerLazySingleton(() => SearchCustomersUseCase(sl()));
  sl.registerLazySingleton(() => GetAllCustomersUseCase(sl()));

  // Features - Supplier
  sl.registerFactory(
    () => SupplierBloc(
      getAllSuppliersUseCase: sl(),
      addSupplierUseCase: sl(),
      updateSupplierUseCase: sl(),
      deleteSupplierUseCase: sl(),
      searchSuppliersUseCase: sl(),
    ),
  );
  sl.registerLazySingleton<SupplierRepository>(
    () => SupplierRepositoryImpl(),
  );
  sl.registerLazySingleton(() => AddSupplierUseCase(sl()));
  sl.registerLazySingleton(() => UpdateSupplierUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSupplierUseCase(sl()));
  sl.registerLazySingleton(() => SearchSuppliersUseCase(sl()));
  sl.registerLazySingleton(() => GetAllSuppliersUseCase(sl()));

  // Features - Employees
  sl.registerFactory(() => EmployeeBloc(repository: sl()));

  // Features - M-Pesa
  sl.registerLazySingleton<MpesaRepositoryImpl>(() => MpesaRepositoryImpl());
  sl.registerFactory(() => MpesaBloc(repository: sl()));
}
