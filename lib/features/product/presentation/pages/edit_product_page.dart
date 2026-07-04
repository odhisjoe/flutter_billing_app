import 'dart:convert';
import 'dart:io';

import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late String _name;
  late String _barcode;
  late String _sku;
  late double _buyingPrice;
  late double _price;
  late int _stock;
  late int _minStockLevel;
  late String _category;
  late String _supplier;
  String? _assignedTo;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _barcode = widget.product.barcode;
    _sku = widget.product.sku ?? '';
    _buyingPrice = widget.product.buyingPrice;
    _price = widget.product.price;
    _stock = widget.product.stock;
    _minStockLevel = widget.product.minStockLevel;
    _category = widget.product.category ?? 'General';
    _supplier = widget.product.supplier ?? '';
    _assignedTo = widget.product.assignedTo;
    _imagePath = widget.product.imageUrl;
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sourceOption(Icons.camera_alt, 'Camera', ImageSource.camera),
            _sourceOption(Icons.photo_library, 'Gallery', ImageSource.gallery),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = picked.mimeType ?? 'image/jpeg';
        setState(() => _imagePath = 'data:$mime;base64,$b64');
      } else {
        setState(() => _imagePath = picked.path);
      }
    }
  }

  Widget _sourceOption(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedProduct = widget.product.copyWith(
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
        minStockLevel: _minStockLevel,
        category: _category,
        imageUrl: _imagePath,
        sku: _sku.isNotEmpty ? _sku : null,
        buyingPrice: _buyingPrice,
        supplier: _supplier.isNotEmpty ? _supplier : null,
        assignedTo: _assignedTo,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  Widget _buildProductImage() {
    if (_imagePath == null || _imagePath!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('Tap to change product image',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      );
    }
    final isNetwork = kIsWeb ||
        _imagePath!.startsWith('http://') ||
        _imagePath!.startsWith('https://') ||
        _imagePath!.startsWith('data:');
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: isNetwork
              ? Image.network(
                  _imagePath!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              : Image.file(
                  File(_imagePath!),
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 40, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text('Tap to change product image',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'General',
      'Electronics',
      'Groceries',
      'Clothing',
      'Books',
      'Furniture',
      'Pharmacy',
    ];

    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 32, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Product Image'),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid),
                      ),
                      child: _buildProductImage(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'Scan or enter barcode',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a barcode';
                            if (v.length < 4) return 'Barcode too short';
                            return null;
                          },
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () async {
                            final result =
                                await context.push<String>('/scanner');
                            if (result != null && result.isNotEmpty) {
                              setState(() => _barcode = result);
                            }
                          },
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),

                  const InputLabel(text: 'Product Name'),

                  TextFormField(
                    initialValue: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),

                  const InputLabel(text: 'Category'),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      hintText: 'Select category',
                    ),
                    items: categories
                        .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat,
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                    onSaved: (value) {
                      if (value != null) _category = value;
                    },
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'SKU'),
                  TextFormField(
                    initialValue: _sku,
                    decoration: const InputDecoration(
                      hintText: 'e.g. SKU-001',
                    ),
                    onSaved: (value) => _sku = value ?? '',
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Buying Price'),
                  TextFormField(
                    initialValue:
                        _buyingPrice > 0 ? _buyingPrice.toStringAsFixed(2) : '',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: 'KES ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) =>
                        _buyingPrice = double.tryParse(value ?? '0') ?? 0,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Selling Price'),
                  TextFormField(
                    initialValue: _price.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: 'KES ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Stock Quantity'),
                  TextFormField(
                    initialValue: _stock.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (value) =>
                        _stock = int.tryParse(value ?? '0') ?? 0,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Min Stock Level'),
                  TextFormField(
                    initialValue: _minStockLevel.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (value) =>
                        _minStockLevel = int.tryParse(value ?? '0') ?? 0,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Supplier'),
                  TextFormField(
                    initialValue: _supplier,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Supplier name',
                    ),
                    onSaved: (value) => _supplier = value ?? '',
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Assigned To'),
                  DropdownButtonFormField<String?>(
                    initialValue: _assignedTo,
                    decoration: const InputDecoration(hintText: 'Unassigned'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(fontSize: 14))),
                      ...HiveDatabase.usersBox.values.where((u) => u.isActive).map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.name, style: const TextStyle(fontSize: 14)),
                      )),
                    ],
                    onChanged: (val) => setState(() => _assignedTo = val),
                    onSaved: (value) => _assignedTo = value,
                  ),
                ],
              ),
            ),
            ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.save,
          label: 'Save Changes',
        ));
  }
}
