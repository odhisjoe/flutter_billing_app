import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 1)
class ShopModel extends Shop {
  const ShopModel({
    required super.name,
    required super.addressLine1,
    required super.addressLine2,
    required super.phoneNumber,
    required super.mpesaTillNumber,
    required super.footerText,
    required super.vatRate,
    required super.kraPin,
    super.logoUrl,
    super.loyaltyPointsPerCurrency = 10,
    super.currencyPerPoint = 100,
  });

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
