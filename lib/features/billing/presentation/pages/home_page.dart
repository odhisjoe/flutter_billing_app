import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/database/secondary_db.dart';
import 'package:billing_app/features/auth/domain/entities/user.dart';
import 'package:billing_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:billing_app/features/inventory/data/models/inventory_transaction_model.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:billing_app/core/utils/barcode_scanner_service.dart';
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

import '../../../../core/bloc/sync_status_cubit.dart';
import '../../../../core/services/sync_status.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../customer/data/models/customer_model.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/cart_item.dart';
import '../widgets/payment_receipt_modal.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Items';
  List<CartItem>? _heldOrder;
  String? _addingProductId;
  String? _hoveredPayment;
  Timer? _searchDebounce;
  StreamSubscription<String>? _barcodeSub;

  @override
  void initState() {
    super.initState();
    _barcodeSub = BarcodeScannerService().onBarcodeScanned.listen((barcode) {
      if (mounted) {
        context.read<BillingBloc>().add(ScanBarcodeEvent(barcode));
      }
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: BlocBuilder<ShopBloc, ShopState>(
          builder: (context, shopState) {
            final logoUrl = shopState is ShopLoaded ? shopState.shop.logoUrl ?? '' : '';
            final shopName = shopState is ShopLoaded ? shopState.shop.name : 'Point of Sale';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logoUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 28, height: 28,
                        child: logoUrl.startsWith('data:') || logoUrl.startsWith('http')
                            ? Image.network(logoUrl, fit: BoxFit.cover)
                            : Image.file(File(logoUrl), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(shopName, overflow: TextOverflow.ellipsis),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode (continuous)',
            onPressed: _handleBarcodeScan,
          ),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              final isAdmin = authState.user?.role == UserRole.admin;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.dashboard),
                      tooltip: 'Admin',
                      onPressed: () => context.push('/admin'),
                    ),
                  BlocBuilder<SyncStatusCubit, SyncStatus>(
                    builder: (context, status) {
                      IconData icon;
                      Color color;
                      switch (status) {
                        case SyncStatus.connected:
                          icon = Icons.cloud_done;
                          color = Colors.green;
                        case SyncStatus.syncing:
                          icon = Icons.cloud_sync;
                          color = Colors.orange;
                        case SyncStatus.connecting:
                          icon = Icons.cloud_upload;
                          color = Colors.orange;
                        case SyncStatus.error:
                          icon = Icons.cloud_off;
                          color = Colors.red;
                        case SyncStatus.disconnected:
                          icon = Icons.cloud_outlined;
                          color = Colors.grey;
                      }
                      return IconButton(
                        icon: Icon(icon, color: color, size: 20),
                        tooltip: 'Cloud: ${status.name}',
                        onPressed: () => context.push('/settings/firebase-link'),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Sign out',
                    onPressed: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BillingBloc, BillingState>(
        listener: (context, state) {
          if (state.lastAddedProductName != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.lastAddedProductName} added to cart'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<BillingBloc>().add(ClearLastAddedProductEvent());
          }
          if (state.printSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt printed successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<BillingBloc>().add(ClearCartEvent());
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
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
                  String logoUrl = '';

                  if (shopState is ShopLoaded) {
                    mpesaTillNumber = shopState.shop.mpesaTillNumber;
                    vatRate = shopState.shop.vatRate;
                    shopName = shopState.shop.name;
                    address1 = shopState.shop.addressLine1;
                    address2 = shopState.shop.addressLine2;
                    phone = shopState.shop.phoneNumber;
                    footer = shopState.shop.footerText;
                    kraPin = shopState.shop.kraPin;
                    logoUrl = shopState.shop.logoUrl ?? '';
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
                              child: _buildLeftPanel(context,
                                  filteredProducts, billingState, isMobile),
                            ),
                            Expanded(
                              flex: 5,
                              child: _buildRightPanel(context, billingState,
                                  shopState, mpesaTillNumber, vatRate, shopName,
                                  address1, address2, phone, footer, kraPin, logoUrl, true),
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
                            child: _buildLeftPanel(context,
                                filteredProducts, billingState, isTablet),
                          ),
                          Expanded(
                            flex: isTablet ? 2 : 1,
                            child: _buildRightPanel(context, billingState,
                                shopState, mpesaTillNumber, vatRate, shopName,
                                address1, address2, phone, footer, kraPin, logoUrl),
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

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }

  double _gridAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 0.7;
    if (width < 600) return 0.8;
    return 0.9;
  }

  Widget _buildLeftPanel(BuildContext context, List<Product> products,
      BillingState billingState, bool isCompact) {
    final categories = _getCategories(
        context.read<ProductBloc>().state.products);
    final cols = _gridColumns(context);
    final aspectRatio = _gridAspectRatio(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 16),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _searchQuery = v);
              });
            },
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey[50],
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _selectedCategory;
              return FilterChip(
                label: Text(cat, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: Colors.grey[200],
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: products.isEmpty
              ? _buildEmptyProducts()
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
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
          Icon(Icons.inventory_2, size: 32, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('No products found',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.push('/products/add'),
            child: const Text('Add Product', style: TextStyle(fontSize: 11)),
          ),
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: _cardImage(product)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 9)),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppConstants.formatPrice(product.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 10),
                        padding: const EdgeInsets.all(2),
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

  Widget _cardImage(Product product) {
    final imageUrl = product.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    if (!hasImage) return _cardInitial(product);

    final useNetwork = kIsWeb ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:');

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: useNetwork
          ? Image.network(imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _cardInitial(product))
          : Image.file(File(imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _cardInitial(product)),
    );
  }

  Widget _cardInitial(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.primaries[
                product.name.hashCode % Colors.primaries.length]
            .withAlpha(25),
      ),
      child: Center(
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.primaries[
                product.name.hashCode % Colors.primaries.length],
          ),
        ),
      ),
    );
  }

  Widget _cartItemThumbnail(Product product) {
    final imageUrl = product.imageUrl!;
    final useNetwork = kIsWeb ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:');
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: useNetwork
          ? Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _cartItemInitial(product))
          : Image.file(File(imageUrl), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _cartItemInitial(product)),
    );
  }

  Widget _cartItemInitial(Product product) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.primaries[
                product.name.hashCode % Colors.primaries.length]
            .withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 11,
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
      String logoUrl,
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
          if (_heldOrder != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.restore, size: 12, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Held order (${_heldOrder!.length} items)',
                        style: TextStyle(fontSize: 10, color: Colors.orange[800])),
                  ),
                  GestureDetector(
                    onTap: () => _resumeOrder(context),
                    child: Text('Resume', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart,
                    color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 4),
                const Text('Order',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text('$totalItems items',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                if (billingState.cartItems.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _holdOrder(context, billingState),
                    child: Icon(Icons.pause_circle_outline,
                        color: Colors.orange[400], size: 16),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      context.read<BillingBloc>().add(ClearCartEvent());
                    },
                    child: Icon(Icons.delete_sweep,
                        color: Colors.red[400], size: 16),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text('${billingState.cartItems.length} item(s)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: billingState.cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(6),
                    itemCount: billingState.cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => _buildCartItemCard(
                        context, billingState.cartItems[index]),
                  ),
          ),
          _buildCartFooter(context, billingState, shopState, mpesaTillNumber,
              vatRate, shopName, address1, address2, phone, footer, kraPin, logoUrl),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cartItemThumbnail(item.product),
            ),
          if (!hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cartItemInitial(item.product),
            ),
          Expanded(
            child: Text(item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 11)),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyBtn(Icons.remove, () {
                  if (item.quantity > 1) {
                    context.read<BillingBloc>().add(UpdateQuantityEvent(
                        item.product.id, item.quantity - 1));
                  } else {
                    context.read<BillingBloc>().add(
                        RemoveProductFromCartEvent(item.product.id));
                  }
                }),
                SizedBox(
                  width: 20,
                  child: Text('${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                _qtyBtn(Icons.add, () {
                  context.read<BillingBloc>().add(UpdateQuantityEvent(
                      item.product.id, item.quantity + 1));
                }),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            AppConstants.formatPrice(item.total),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id)),
            child: Icon(Icons.delete_outline, size: 13, color: Colors.red[300]),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: Colors.grey[600]),
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
      String kraPin,
      String logoUrl) {
    return SafeArea(
      top: false,
      child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
          const SizedBox(height: 6),
          if (mpesaTillNumber.isNotEmpty && billingState.cartItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android,
                      size: 14, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('M-Pesa Till: $mpesaTillNumber',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.green[800])),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: _payBtn('Cash', Icons.payments, _hoveredPayment == 'Cash', () => _startPaymentFlow(billingState, shopState, shopName, address1, address2, phone, footer, vatRate, kraPin, mpesaTillNumber, logoUrl))),
              const SizedBox(width: 4),
              Expanded(child: _payBtn('M-Pesa', Icons.phone_android, _hoveredPayment == null || _hoveredPayment == 'M-Pesa', () {
                if (mpesaTillNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('M-Pesa till not configured'), backgroundColor: Colors.orange),
                  );
                } else {
                  _startPaymentFlow(billingState, shopState, shopName, address1, address2, phone, footer, vatRate, kraPin, mpesaTillNumber, logoUrl);
                }
              })),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _payBtn('Card', Icons.credit_card, _hoveredPayment == 'Card', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card payment coming soon'), behavior: SnackBarBehavior.floating),
                );
              })),
              const SizedBox(width: 4),
              Expanded(child: _payBtn('Bank', Icons.account_balance, _hoveredPayment == 'Bank', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bank payment coming soon'), behavior: SnackBarBehavior.floating),
                );
              })),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: billingState.cartItems.isEmpty || billingState.isPrinting
                  ? null
                  : () => _startPaymentFlow(billingState, shopState, shopName,
                      address1, address2, phone, footer, vatRate, kraPin, mpesaTillNumber, logoUrl),
              icon: billingState.isPrinting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, size: 18),
              label: Text(
                  billingState.isPrinting ? 'Printing...' : 'Complete Sale',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),

        ],
      ),
    ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool isTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isTotal ? 11 : 10,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.black87 : Colors.grey[500],
              )),
          Text(value,
              style: TextStyle(
                fontSize: isTotal ? 14 : 11,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: isTotal ? AppTheme.primaryColor : Colors.black87,
              )),
        ],
      ),
    );
  }

  Widget _payBtn(String label, IconData icon, bool selected, VoidCallback onTap) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredPayment = label),
      onExit: (_) => setState(() => _hoveredPayment = null),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: selected ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? Colors.green[300]! : Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: selected ? Colors.green[700] : Colors.grey[600]),
              const SizedBox(width: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? Colors.green[700] : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  void _holdOrder(BuildContext context, BillingState billingState) {
    if (billingState.cartItems.isEmpty) return;
    setState(() {
      _heldOrder = List.from(billingState.cartItems);
    });
    context.read<BillingBloc>().add(ClearCartEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order held'), backgroundColor: Colors.orange, duration: Duration(seconds: 1)),
    );
  }

  void _resumeOrder(BuildContext context) {
    if (_heldOrder == null) return;
    final held = _heldOrder!;
    setState(() => _heldOrder = null);
    final bloc = context.read<BillingBloc>();
    for (final item in held) {
      bloc.add(AddProductToCartEvent(item.product));
    }
    for (final item in held) {
      if (item.quantity > 1) {
        bloc.add(UpdateQuantityEvent(item.product.id, item.quantity));
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order resumed'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
    );
  }

  Future<void> _saveSaleAndUpdateStock(
      BuildContext context, BillingState state,
      {PaymentBreakdown? paymentOverride, String? saleIdOverride}) async {
    try {
      final useCase = sl<SaveSaleUseCase>();
      final shopState = context.read<ShopBloc>().state;
      final shopName =
          shopState is ShopLoaded ? shopState.shop.name : '';

      final p = paymentOverride ?? state.payment;
      final currentUser = context.read<AuthBloc>().state.user;

      int? pointsPerCurrency;
      if (shopState is ShopLoaded) {
        pointsPerCurrency = shopState.shop.loyaltyPointsPerCurrency;
      }

      final sale = Sale(
        id: saleIdOverride ?? const Uuid().v4(),
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
        customerId: p?.customerId,
        customerName: p?.customerName,
        cashierId: currentUser?.id,
        cashierName: currentUser?.name,
      );

      await useCase(sale);

      // Enqueue to sync queue for secondary cloud sync
      try {
        await SecondaryDb.enqueueSync(
          entityType: 'sale',
          entityId: sale.id,
          operation: 'create',
          payload: jsonEncode({
            'id': sale.id,
            'date': sale.date.toIso8601String(),
            'items': sale.items.map((i) => {
              'productId': i.productId,
              'productName': i.productName,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
            }).toList(),
            'subtotal': sale.subtotal,
            'grandTotal': sale.grandTotal,
            'cash': sale.cash,
            'mpesa': sale.mpesa,
            'card': sale.card,
            'bank': sale.bank,
            'shopName': sale.shopName,
            'cashierId': sale.cashierId,
            'cashierName': sale.cashierName,
          }),
        );
      } catch (_) {}

      if (p?.customerId != null && pointsPerCurrency != null && pointsPerCurrency > 0) {
        final model = HiveDatabase.customerBox.get(p!.customerId);
        if (model != null) {
          final customer = model.toEntity();
          final pointsEarned = state.grandTotal ~/ pointsPerCurrency;
          if (pointsEarned > 0) {
            final updatedCustomer = customer.copyWith(
              loyaltyPoints: customer.loyaltyPoints + pointsEarned,
              totalSpent: customer.totalSpent + state.grandTotal,
            );
            final updatedModel = CustomerModel.fromEntity(updatedCustomer);
            await HiveDatabase.customerBox.put(updatedModel.id, updatedModel);
          }
        }
      }

      for (final item in state.cartItems) {
        final product = item.product;
        if (product.stock >= item.quantity) {
          final newStock = product.stock - item.quantity;
          final updated = product.copyWith(stock: newStock);
          final model = ProductModel.fromEntity(updated);
          await HiveDatabase.productBox.put(model.id, model);

          await HiveDatabase.inventoryBox.put(
            const Uuid().v4(),
            InventoryTransactionModel(
              id: const Uuid().v4(),
              productId: product.id,
              productName: product.name,
              type: 'sale',
              quantity: -item.quantity,
              stockBefore: product.stock,
              stockAfter: newStock,
              reference: sale.id,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      if (context.mounted) {
        context.read<ProductBloc>().add(LoadProducts());
      }
    } catch (e) {
      debugPrint('[SALE_SAVE] Exception: $e');
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
    String logoUrl,
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
      logoUrl: logoUrl.isNotEmpty ? logoUrl : null,
      cashierName: currentUser?.name,
    );

    if (!mounted) return;

    await _saveSaleAndUpdateStock(context, billingState, paymentOverride: payment);

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
  }

  Future<void> _handleBarcodeScan() async {
    await context.push('/scanner', extra: {'continuous': true});
  }

}
