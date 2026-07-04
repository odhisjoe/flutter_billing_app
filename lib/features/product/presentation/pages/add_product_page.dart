import 'dart:convert';
import 'dart:io';

import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  String _name = '';
  String _barcode = '';
  String _sku = '';
  double _buyingPrice = 0.0;
  double _price = 0.0;
  int _stock = 0;
  int _minStockLevel = 0;
  String _category = 'General';
  String _supplier = '';
  String? _assignedTo;
  String? _imagePath;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
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

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$_barcode" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
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

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  InputDecoration _compact({required String hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey[300]!, style: BorderStyle.solid),
                      ),
                      child: _imagePath != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: _imagePath!.startsWith('data:') || _imagePath!.startsWith('http')
                                      ? Image.network(
                                          _imagePath!,
                                          width: double.infinity,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_imagePath!),
                                          width: double.infinity,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _removeImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(120),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 28, color: Colors.grey[400]),
                                const SizedBox(height: 4),
                                Text('Tap to add image',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500])),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: _compact(hint: 'Scan or enter barcode'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a barcode';
                            if (v.length < 4) return 'Barcode too short';
                            return null;
                          },
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor, size: 20),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _label('Product Name'),
                  TextFormField(
                    decoration: _compact(hint: 'e.g. Basmati Rice'),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 12),
                  _label('Category'),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _compact(hint: 'Select category'),
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
                  const SizedBox(height: 12),
                  _label('SKU'),
                  TextFormField(
                    decoration: _compact(hint: 'e.g. SKU-001'),
                    onSaved: (value) => _sku = value ?? '',
                  ),
                  const SizedBox(height: 12),
                  _label('Buying Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: 'KES ',
                      prefixStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) =>
                        _buyingPrice = double.tryParse(value ?? '0') ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _label('Selling Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: 'KES ',
                      prefixStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 12),
                  _label('Stock Quantity'),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: _compact(hint: '0'),
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
                  const SizedBox(height: 12),
                  _label('Min Stock Level'),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: _compact(hint: '0'),
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
                  const SizedBox(height: 12),
                  _label('Supplier'),
                  TextFormField(
                    decoration: _compact(hint: 'e.g. Supplier name'),
                    onSaved: (value) => _supplier = value ?? '',
                  ),
                  const SizedBox(height: 12),
                  _label('Assigned To'),
                  DropdownButtonFormField<String?>(
                    initialValue: _assignedTo,
                    decoration: _compact(hint: 'Unassigned'),
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
          icon: Icons.add_circle,
          label: 'Add Product',
        ));
  }
}
