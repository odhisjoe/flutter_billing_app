part of 'billing_bloc.dart';

class PaymentBreakdown extends Equatable {
  final double cash;
  final double mpesa;
  final double card;
  final double bank;
  final double change;
  final double grandTotal;
  final String? customerId;
  final String? customerName;

  const PaymentBreakdown({
    required this.cash,
    required this.mpesa,
    required this.card,
    required this.bank,
    required this.change,
    required this.grandTotal,
    this.customerId,
    this.customerName,
  });

  Map<String, dynamic> toMap() => {
        'cash': cash,
        'mpesa': mpesa,
        'card': card,
        'bank': bank,
        'change': change,
        'grandTotal': grandTotal,
        if (customerId != null) 'customerId': customerId,
        if (customerName != null) 'customerName': customerName,
      };

  @override
  List<Object?> get props => [cash, mpesa, card, bank, change, grandTotal, customerId, customerName];
}

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final double vatRate;
  final PaymentBreakdown? payment;
  final double totalAmount;
  final double vatAmount;
  final double grandTotal;
  final String? lastAddedProductName;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.vatRate = 0.0,
    this.payment,
    this.totalAmount = 0,
    this.vatAmount = 0,
    this.grandTotal = 0,
    this.lastAddedProductName,
  });

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    double? vatRate,
    PaymentBreakdown? payment,
    bool clearPayment = false,
    String? lastAddedProductName,
  }) {
    final items = cartItems ?? this.cartItems;
    final rate = vatRate ?? this.vatRate;
    final itemsChanged = cartItems != null;
    final total = itemsChanged
        ? items.fold<num>(0, (s, i) => s + i.total).toDouble()
        : totalAmount;
    return BillingState(
      cartItems: items,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      vatRate: rate,
      payment: clearPayment ? null : (payment ?? this.payment),
      totalAmount: total,
      vatAmount: total * (rate / 100),
      grandTotal: total + (total * (rate / 100)),
      lastAddedProductName: lastAddedProductName,
    );
  }

  @override
  List<Object?> get props => [cartItems, error, isPrinting, printSuccess, vatRate, payment, totalAmount, vatAmount, grandTotal, lastAddedProductName];
}
