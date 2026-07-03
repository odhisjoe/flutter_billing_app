part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  final bool fromScan;
  const AddProductToCartEvent(this.product, {this.fromScan = false});
  @override
  List<Object> get props => [product, fromScan];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

class ClearLastAddedProductEvent extends BillingEvent {}

class SetPaymentBreakdownEvent extends BillingEvent {
  final PaymentBreakdown payment;
  const SetPaymentBreakdownEvent(this.payment);
  @override
  List<Object> get props => [payment];
}

class ClearPaymentEvent extends BillingEvent {
  const ClearPaymentEvent();
  @override
  List<Object> get props => [];
}

class SetVatRateEvent extends BillingEvent {
  final double vatRate;
  const SetVatRateEvent(this.vatRate);
  @override
  List<Object> get props => [vatRate];
}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;
  final double vatRate;
  final double vatAmount;
  final String kraPin;
  final String mpesaTillNumber;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
    required this.vatRate,
    required this.vatAmount,
    required this.kraPin,
    required this.mpesaTillNumber,
  });

  @override
  List<Object> get props =>
      [shopName, address1, address2, phone, footer, vatRate, vatAmount, kraPin, mpesaTillNumber];
}
