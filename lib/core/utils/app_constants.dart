class AppConstants {
  AppConstants._();

  static const String currencyCode = 'KES';
  static const String currencySymbol = 'KES ';

  static String formatPrice(num price) {
    return '$currencySymbol${price.toStringAsFixed(2)}';
  }

  static const String defaultCountryCode = '+254';
  static const String defaultPhoneHint = '+254 712 345 678';
}
