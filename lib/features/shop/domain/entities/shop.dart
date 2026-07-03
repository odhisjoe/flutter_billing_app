import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String mpesaTillNumber;
  final String footerText;
  final double vatRate;
  final String kraPin;
  final String? logoUrl;
  final int loyaltyPointsPerCurrency;
  final int currencyPerPoint;

  const Shop({
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.mpesaTillNumber = '',
    this.footerText = '',
    this.vatRate = 0.0,
    this.kraPin = '',
    this.logoUrl,
    this.loyaltyPointsPerCurrency = 10,
    this.currencyPerPoint = 100,
  });

  Shop copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? mpesaTillNumber,
    String? footerText,
    double? vatRate,
    String? kraPin,
    String? logoUrl,
    int? loyaltyPointsPerCurrency,
    int? currencyPerPoint,
  }) {
    return Shop(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      mpesaTillNumber: mpesaTillNumber ?? this.mpesaTillNumber,
      footerText: footerText ?? this.footerText,
      vatRate: vatRate ?? this.vatRate,
      kraPin: kraPin ?? this.kraPin,
      logoUrl: logoUrl ?? this.logoUrl,
      loyaltyPointsPerCurrency: loyaltyPointsPerCurrency ?? this.loyaltyPointsPerCurrency,
      currencyPerPoint: currencyPerPoint ?? this.currencyPerPoint,
    );
  }

  @override
  List<Object?> get props =>
      [name, addressLine1, addressLine2, phoneNumber, mpesaTillNumber, footerText, vatRate, kraPin, logoUrl, loyaltyPointsPerCurrency, currencyPerPoint];
}
