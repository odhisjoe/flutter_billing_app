import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_driver.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/printer_manager.dart';
import '../../../../core/data/hive_database.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<ClearLastAddedProductEvent>(_onClearLastAddedProduct);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<SetVatRateEvent>(_onSetVatRate);
    on<SetPaymentBreakdownEvent>(_onSetPaymentBreakdown);
    on<ClearPaymentEvent>(_onClearPayment);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product, fromScan: true));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(
          cartItems: backendItems,
          error: null,
          lastAddedProductName:
              event.fromScan ? event.product.name : null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem],
          error: null,
          lastAddedProductName:
              event.fromScan ? event.product.name : null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  void _onClearLastAddedProduct(ClearLastAddedProductEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(lastAddedProductName: null));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();
    final manager = PrinterManager();

    if (!kIsWeb) {
      if (!manager.isConnected) {
        // Try saved PrinterDevice first (USB/Network/Bluetooth)
        final savedDeviceRaw = HiveDatabase.settingsBox.get('printer_device');
        if (savedDeviceRaw != null) {
          try {
            final map = jsonDecode(savedDeviceRaw) as Map<String, dynamic>;
            final typeIndex = map['driverType'] as int? ?? 0;
            final safeTypes = PrinterDriverType.values;
            final device = PrinterDevice(
              name: map['name'] as String? ?? '',
              address: map['address'] as String? ?? '',
              driverType: typeIndex < safeTypes.length ? safeTypes[typeIndex] : PrinterDriverType.usb,
            );
            final connected = await manager.connect(device);
            if (!connected) {
              emit(state.copyWith(
                  error: 'Failed to auto-connect to saved printer!'));
              return;
            }
          } catch (_) {
            // Fallback to legacy MAC approach
          }
        }

        if (!manager.isConnected) {
          // Legacy: try saved Bluetooth MAC
          final savedMac = HiveDatabase.settingsBox.get('printer_mac');
          if (savedMac != null) {
            final connected = await printerHelper.connect(savedMac);
            if (!connected) {
              emit(state.copyWith(
                  error: 'Failed to auto-connect to printer!'));
              return;
            }
          } else {
            emit(state.copyWith(
                error: 'Printer not connected & no saved printer found!'));
            return;
          }
        }
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: state.totalAmount,
          vatRate: event.vatRate,
          vatAmount: event.vatAmount,
          kraPin: event.kraPin,
          footer: event.footer,
          payment: state.payment?.toMap());

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(isPrinting: false, printSuccess: false,
          error: 'Print failed: $e'));
    }
  }

  void _onSetVatRate(SetVatRateEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(vatRate: event.vatRate));
  }

  void _onSetPaymentBreakdown(
      SetPaymentBreakdownEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(payment: event.payment));
  }

  void _onClearPayment(ClearPaymentEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(clearPayment: true));
  }
}
