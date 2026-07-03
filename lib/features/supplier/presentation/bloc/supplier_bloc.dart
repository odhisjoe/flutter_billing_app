import 'package:flutter_bloc/flutter_bloc.dart';
import 'supplier_event.dart';
import 'supplier_state.dart';
import '../../domain/usecases/supplier_usecases.dart';

class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  final GetAllSuppliersUseCase getAllSuppliersUseCase;
  final AddSupplierUseCase addSupplierUseCase;
  final UpdateSupplierUseCase updateSupplierUseCase;
  final DeleteSupplierUseCase deleteSupplierUseCase;
  final SearchSuppliersUseCase searchSuppliersUseCase;

  SupplierBloc({
    required this.getAllSuppliersUseCase,
    required this.addSupplierUseCase,
    required this.updateSupplierUseCase,
    required this.deleteSupplierUseCase,
    required this.searchSuppliersUseCase,
  }) : super(const SupplierState()) {
    on<LoadSuppliers>(_onLoadSuppliers);
    on<AddSupplier>(_onAddSupplier);
    on<UpdateSupplier>(_onUpdateSupplier);
    on<DeleteSupplier>(_onDeleteSupplier);
    on<SearchSuppliers>(_onSearchSuppliers);
  }

  void _onLoadSuppliers(LoadSuppliers event, Emitter<SupplierState> emit) {
    final suppliers = getAllSuppliersUseCase();
    emit(SupplierState(suppliers: suppliers));
  }

  Future<void> _onAddSupplier(AddSupplier event, Emitter<SupplierState> emit) async {
    await addSupplierUseCase(event.supplier);
    add(const LoadSuppliers());
  }

  Future<void> _onUpdateSupplier(UpdateSupplier event, Emitter<SupplierState> emit) async {
    await updateSupplierUseCase(event.supplier);
    add(const LoadSuppliers());
  }

  Future<void> _onDeleteSupplier(DeleteSupplier event, Emitter<SupplierState> emit) async {
    await deleteSupplierUseCase(event.id);
    add(const LoadSuppliers());
  }

  void _onSearchSuppliers(SearchSuppliers event, Emitter<SupplierState> emit) {
    final suppliers = searchSuppliersUseCase(event.query);
    emit(SupplierState(suppliers: suppliers));
  }
}
