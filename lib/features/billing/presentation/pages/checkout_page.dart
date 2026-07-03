import 'dart:io';

import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/reports/domain/entities/sale.dart';
import 'package:billing_app/features/reports/domain/usecases/sale_usecases.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/cart_item.dart';
import '../widgets/payment_receipt_modal.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Items';
  String? _addingProductId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static Widget _productImage(String? imageUrl,
      {double size = 40, double radius = 8}) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    final isNetwork = kIsWeb ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: isNetwork
          ? Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())
          : Image.file(File(imageUrl), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.read<BillingBloc>().add(ClearCartEvent());
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Point of Sale'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () {
              context.read<BillingBloc>().add(ClearCartEvent());
              context.go('/');
            },
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Receipt printed'),
                      backgroundColor: Colors.green),
                );
              }
              context.read<BillingBloc>().add(ClearCartEvent());
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(state.error!),
                    backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, billingState) {
            return BlocBuilder<ProductBloc, ProductState>(
              builder: (context, productState) {
                final products = productState.products;
                final filteredProducts = _filterProducts(products);

                return BlocBuilder<ShopBloc, ShopState>(
                  builder: (context, shopState) {
                    String mpesaTillNumber = '';
                    double vatRate = 0.0;
                    String shopName = '';
                    String address1 = '';
                    String address2 = '';
                    String phone = '';
                    String footer = '';
                    String kraPin = '';

                    if (shopState is ShopLoaded) {
                      mpesaTillNumber = shopState.shop.mpesaTillNumber;
                      vatRate = shopState.shop.vatRate;
                      shopName = shopState.shop.name;
                      address1 = shopState.shop.addressLine1;
                      address2 = shopState.shop.addressLine2;
                      phone = shopState.shop.phoneNumber;
                      footer = shopState.shop.footerText;
                      kraPin = shopState.shop.kraPin;
                      if (context.read<BillingBloc>().state.vatRate != vatRate) {
                        context.read<BillingBloc>().add(SetVatRateEvent(vatRate));
                      }
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildLeftPanel(
                                    context, filteredProducts, billingState),
                              ),
                              Expanded(
                                flex: 4,
                                child: _buildRightPanel(context, billingState,
                                    shopState, mpesaTillNumber, vatRate, shopName,
                                    address1, address2, phone, footer, kraPin, true),
                              ),
                            ],
                          );
                        }
                        final isTablet = constraints.maxWidth < 900;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: isTablet ? 3 : 2,
                              child: _buildLeftPanel(
                                  context, filteredProducts, billingState),
                            ),
                            Expanded(
                              flex: isTablet ? 2 : 1,
                              child: _buildRightPanel(context, billingState,
                                  shopState, mpesaTillNumber, vatRate, shopName,
                                  address1, address2, phone, footer, kraPin),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    var filtered = products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q)).toList();
    }
    if (_selectedCategory != 'All Items') {
      filtered = filtered
          .where((p) => p.category?.toLowerCase() == _selectedCategory.toLowerCase())
          .toList();
    }
    return filtered;
  }

  Widget _buildLeftPanel(BuildContext context, List<Product> products,
      BillingState billingState) {
    final categories = _getCategories(
        context.read<ProductBloc>().state.products);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products or scan barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _handleBarcodeScan,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.grey[50],
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _selectedCategory;
              return FilterChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: Colors.grey[200],
                side: BorderSide.none,
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: products.isEmpty
              ? _buildEmptyProducts()
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _buildProductCard(context, products[index]),
                ),
        ),
      ],
    );
  }

  List<String> _getCategories(List<Product> products) {
    final cats = products.map((p) => p.category).whereType<String>().toSet().toList();
    cats.sort();
    return ['All Items', ...cats];
  }

  Widget _buildEmptyProducts() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No products found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      key: ValueKey(product.sku ?? product.id),
      onTap: () {
        if (_addingProductId == product.id) return;
        _addingProductId = product.id;
        context.read<BillingBloc>().add(AddProductToCartEvent(product));
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _addingProductId = null);
        });
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _productImageArea(product)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Stock: ${product.stock}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppConstants.formatPrice(product.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImageArea(Product product) {
    final imageUrl = product.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (!hasImage) return _productInitial(product);

    final useNetwork = kIsWeb ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:');

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: useNetwork
          ? Image.network(imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _productInitial(product))
          : Image.file(File(imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _productInitial(product)),
    );
  }

  Widget _productInitial(Product product) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Center(
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.primaries[
                product.name.hashCode % Colors.primaries.length],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(
      BuildContext context,
      BillingState billingState,
      ShopState shopState,
      String mpesaTillNumber,
      double vatRate,
      String shopName,
      String address1,
      String address2,
      String phone,
      String footer,
      String kraPin,
      [bool isMobile = false]) {
    final totalItems =
        billingState.cartItems.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: isMobile
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(-2, 0)),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Current Order',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                Text('$totalItems items',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (billingState.cartItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.read<BillingBloc>().add(ClearCartEvent());
                    },
                    child: Icon(Icons.delete_sweep,
                        color: Colors.red[400], size: 20),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: billingState.cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: billingState.cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildCartItemCard(
                        context, billingState.cartItems[index]),
                  ),
          ),
          _buildCartFooter(context, billingState, shopState, mpesaTillNumber,
              vatRate, shopName, address1, address2, phone, footer, kraPin),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Cart is empty',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Tap a product to add it',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    final hasImage = item.product.imageUrl != null &&
        item.product.imageUrl!.isNotEmpty;

    return Container(
      key: ValueKey(item.product.id),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _productImage(item.product.imageUrl, size: 40),
            ),
          if (!hasImage)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.primaries[
                        item.product.name.hashCode % Colors.primaries.length]
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  item.product.name.isNotEmpty
                      ? item.product.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.primaries[
                          item.product.name.hashCode %
                              Colors.primaries.length]),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  AppConstants.formatPrice(item.product.price),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (item.quantity > 1) {
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.product.id, item.quantity - 1));
                    } else {
                      context.read<BillingBloc>().add(
                          RemoveProductFromCartEvent(item.product.id));
                    }
                  },
                ),
                SizedBox(
                  width: 28,
                  child: Text('${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                _qtyButton(
                  icon: Icons.add,
                  onTap: () {
                    context.read<BillingBloc>().add(UpdateQuantityEvent(
                        item.product.id, item.quantity + 1));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              AppConstants.formatPrice(item.total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildCartFooter(
      BuildContext context,
      BillingState billingState,
      ShopState shopState,
      String mpesaTillNumber,
      double vatRate,
      String shopName,
      String address1,
      String address2,
      String phone,
      String footer,
      String kraPin) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTotalRow('Subtotal',
              AppConstants.formatPrice(billingState.totalAmount), false),
          if (vatRate > 0)
            _buildTotalRow(
                'VAT (${vatRate.toStringAsFixed(1)}%)',
                AppConstants.formatPrice(billingState.vatAmount),
                false),
          _buildTotalRow(
              'Total',
              AppConstants.formatPrice(billingState.grandTotal),
              true),
          const SizedBox(height: 12),
          if (mpesaTillNumber.isNotEmpty && billingState.cartItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android,
                      size: 20, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('M-Pesa Till: $mpesaTillNumber',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.green[800])),
                        Text(
                            'Amount: ${AppConstants.formatPrice(billingState.grandTotal)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _paymentButton(
                  icon: Icons.payments,
                  label: 'Cash',
                  isSelected: false,
                  onTap: () => _startPaymentFlow(billingState, shopState, shopName, address1, address2, phone, footer, vatRate, kraPin, mpesaTillNumber),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _paymentButton(
                  icon: Icons.phone_android,
                  label: 'M-Pesa',
                  isSelected: true,
                  onTap: () {
                    if (mpesaTillNumber.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('M-Pesa till not configured'),
                            backgroundColor: Colors.orange),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _paymentButton(
                  icon: Icons.credit_card,
                  label: 'Card',
                  isSelected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Card payment coming soon'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _paymentButton(
                  icon: Icons.account_balance,
                  label: 'Bank',
                  isSelected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Bank payment coming soon'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: billingState.cartItems.isEmpty
                  ? null
                  : () => _startPaymentFlow(billingState, shopState, shopName, address1, address2, phone, footer, vatRate, kraPin, mpesaTillNumber),
              icon: billingState.isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                  billingState.isPrinting ? 'Printing...' : 'Complete Sale',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withAlpha(60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool isTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.black87 : Colors.grey[500],
              )),
          Text(value,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: isTotal ? AppTheme.primaryColor : Colors.black87,
              )),
        ],
      ),
    );
  }

  Widget _paymentButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.green[300]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.green[700] : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.green[700] : Colors.grey[600],
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSaleAndUpdateStock(
      BuildContext context, BillingState state,
      {PaymentBreakdown? paymentOverride}) async {
    try {
      final useCase = sl<SaveSaleUseCase>();
      final shopState = context.read<ShopBloc>().state;
      final shopName =
          shopState is ShopLoaded ? shopState.shop.name : '';

      final p = paymentOverride ?? state.payment;
      final currentUser = context.read<AuthBloc>().state.user;

      final sale = Sale(
        id: const Uuid().v4(),
        date: DateTime.now(),
        items: state.cartItems
            .map((item) => SaleItem(
                  productId: item.product.id,
                  productName: item.product.name,
                  quantity: item.quantity,
                  unitPrice: item.product.price,
                  buyingPrice: item.product.buyingPrice,
                  total: item.total,
                ))
            .toList(),
        subtotal: state.totalAmount,
        vatRate: state.vatRate,
        vatAmount: state.vatAmount,
        grandTotal: state.grandTotal,
        cash: p?.cash ?? 0,
        mpesa: p?.mpesa ?? 0,
        card: p?.card ?? 0,
        bank: p?.bank ?? 0,
        change: p?.change ?? 0,
        shopName: shopName,
        cashierId: currentUser?.id,
        cashierName: currentUser?.name,
      );

      debugPrint('[SALE_SAVE] Sale ID: ${sale.id}, Items: ${sale.items.length}, Total: ${sale.grandTotal}');

      final saveResult = await useCase(sale);
      saveResult.fold(
        (failure) => debugPrint('[SALE_SAVE] Failed: $failure'),
        (_) => debugPrint('[SALE_SAVE] Saved successfully'),
      );

      for (final item in state.cartItems) {
        final product = item.product;
        if (product.stock >= item.quantity) {
          final updated = product.copyWith(stock: product.stock - item.quantity);
          final model = ProductModel.fromEntity(updated);
          await HiveDatabase.productBox.put(model.id, model);
        }
      }

      if (context.mounted) {
        context.read<ProductBloc>().add(LoadProducts());
      }
    } catch (e) {
      debugPrint('[SALE_SAVE] Exception: $e');
    }
  }

  Future<void> _handleBarcodeScan() async {
    while (mounted) {
      final result = await context.push<String>('/scanner');
      if (result == null || !mounted) break;
      context.read<BillingBloc>().add(ScanBarcodeEvent(result));
    }
  }

  Future<void> _startPaymentFlow(
    BillingState billingState,
    ShopState shopState,
    String shopName,
    String address1,
    String address2,
    String phone,
    String footer,
    double vatRate,
    String kraPin,
    String mpesaTillNumber,
  ) async {
    if (billingState.cartItems.isEmpty) return;
    if (shopState is! ShopLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Shop details not loaded'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final payment = await showPaymentModal(context, billingState.grandTotal);
    if (payment == null || !mounted) return;

    final currentUser = context.read<AuthBloc>().state.user;
    final shouldPrint = await showReceiptPreview(
      context,
      shopName: shopName,
      address1: address1,
      address2: address2,
      phone: phone,
      kraPin: kraPin,
      vatRate: vatRate,
      vatAmount: billingState.vatAmount,
      footer: footer,
      cartItems: billingState.cartItems,
      payment: payment,
      cashierName: currentUser?.name,
    );

    if (!mounted) return;

    await _saveSaleAndUpdateStock(context, billingState, paymentOverride: payment);

    String summary = 'Sale complete!';
    final parts = <String>[];
    if (payment.cash > 0) parts.add('Cash: ${AppConstants.formatPrice(payment.cash)}');
    if (payment.mpesa > 0) parts.add('M-Pesa: ${AppConstants.formatPrice(payment.mpesa)}');
    if (payment.card > 0) parts.add('Card: ${AppConstants.formatPrice(payment.card)}');
    if (payment.bank > 0) parts.add('Bank: ${AppConstants.formatPrice(payment.bank)}');
    if (payment.change > 0) parts.add('Change: ${AppConstants.formatPrice(payment.change)}');
    if (parts.isNotEmpty) summary = parts.join(' | ');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(summary), backgroundColor: Colors.green),
      );
    }

    if (shouldPrint == true && mounted) {
      context.read<BillingBloc>().add(SetPaymentBreakdownEvent(payment));
      context.read<BillingBloc>().add(PrintReceiptEvent(
            shopName: shopName,
            address1: address1,
            address2: address2,
            phone: phone,
            footer: footer,
            vatRate: vatRate,
            vatAmount: billingState.vatAmount,
            kraPin: kraPin,
            mpesaTillNumber: mpesaTillNumber,
          ));
    }

    if (mounted) {
      context.read<BillingBloc>().add(ClearCartEvent());
    }
  }
}
