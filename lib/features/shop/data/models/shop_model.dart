import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 1)
class ShopModel extends Shop {
  @override
  @HiveField(0)
  final String name;
  @override
  @HiveField(1)
  final String addressLine1;
  @override
  @HiveField(2)
  final String addressLine2;
  @override
  @HiveField(3)
  final String phoneNumber;
  @override
  @HiveField(4)
  final String mpesaTillNumber;
  @override
  @HiveField(5)
  final String footerText;
  @override
  @HiveField(6)
  final double vatRate;
  @override
  @HiveField(7)
  final String kraPin;
  @override
  @HiveField(8)
  final String? logoUrl;
  @override
  @HiveField(9)
  final int loyaltyPointsPerCurrency;
  @override
  @HiveField(10)
  final int currencyPerPoint;

  const ShopModel({
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.phoneNumber,
    required this.mpesaTillNumber,
    required this.footerText,
    required this.vatRate,
    required this.kraPin,
    this.logoUrl,
    this.loyaltyPointsPerCurrency = 10,
    this.currencyPerPoint = 100,
  }) : super(
          name: name,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          phoneNumber: phoneNumber,
          mpesaTillNumber: mpesaTillNumber,
          footerText: footerText,
          vatRate: vatRate,
          kraPin: kraPin,
          logoUrl: logoUrl,
          loyaltyPointsPerCurrency: loyaltyPointsPerCurrency,
          currencyPerPoint: currencyPerPoint,
        );

  factory ShopModel.fromEntity(Shop shop) {
    return ShopModel(
      name: shop.name,
      addressLine1: shop.addressLine1,
      addressLine2: shop.addressLine2,
      phoneNumber: shop.phoneNumber,
      mpesaTillNumber: shop.mpesaTillNumber,
      footerText: shop.footerText,
      vatRate: shop.vatRate,
      kraPin: shop.kraPin,
      logoUrl: shop.logoUrl,
      loyaltyPointsPerCurrency: shop.loyaltyPointsPerCurrency,
      currencyPerPoint: shop.currencyPerPoint,
    );
  }

  Shop toEntity() => this;
}
