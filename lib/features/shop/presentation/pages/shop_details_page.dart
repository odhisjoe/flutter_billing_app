import 'dart:convert';
import 'dart:io';

import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/app_constants.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late TextEditingController _nameController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _mpesaController;
  late TextEditingController _vatRateController;
  late TextEditingController _kraPinController;
  late TextEditingController _footerController;
  late TextEditingController _loyaltyPointsPerCurrencyController;
  late TextEditingController _currencyPerPointController;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _mpesaController = TextEditingController();
    _vatRateController = TextEditingController();
    _kraPinController = TextEditingController();
    _footerController = TextEditingController();
    _loyaltyPointsPerCurrencyController = TextEditingController();
    _currencyPerPointController = TextEditingController();

    // Load shop data
    context.read<ShopBloc>().add(LoadShopEvent());
  }

  Future<void> _pickLogo() async {
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
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = picked.mimeType ?? 'image/jpeg';
        setState(() => _logoPath = 'data:$mime;base64,$b64');
      } else {
        setState(() => _logoPath = picked.path);
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

  void _updateControllers(Shop shop) {
    if (_nameController.text.isEmpty && shop.name.isNotEmpty) {
      _nameController.text = shop.name;
      _address1Controller.text = shop.addressLine1;
      _address2Controller.text = shop.addressLine2;
      _phoneController.text = shop.phoneNumber;
      _mpesaController.text = shop.mpesaTillNumber;
      _vatRateController.text = shop.vatRate > 0 ? shop.vatRate.toStringAsFixed(1) : '';
      _kraPinController.text = shop.kraPin;
      _footerController.text = shop.footerText;
      _loyaltyPointsPerCurrencyController.text = shop.loyaltyPointsPerCurrency.toString();
      _currencyPerPointController.text = shop.currencyPerPoint.toString();
      if (shop.logoUrl != null) _logoPath = shop.logoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _mpesaController.dispose();
    _vatRateController.dispose();
    _kraPinController.dispose();
    _footerController.dispose();
    _loyaltyPointsPerCurrencyController.dispose();
    _currencyPerPointController.dispose();
    super.dispose();
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final vatText = _vatRateController.text.trim();
      final vatRate = double.tryParse(vatText) ?? 0.0;

      final loyaltyPtsPerCurrency = int.tryParse(_loyaltyPointsPerCurrencyController.text.trim()) ?? 10;
      final currencyPerPt = int.tryParse(_currencyPerPointController.text.trim()) ?? 100;

      final shop = Shop(
        name: _nameController.text,
        addressLine1: _address1Controller.text,
        addressLine2: _address2Controller.text,
        phoneNumber: _phoneController.text,
        mpesaTillNumber: _mpesaController.text,
        footerText: _footerController.text,
        vatRate: vatRate,
        kraPin: _kraPinController.text,
        logoUrl: _logoPath,
        loyaltyPointsPerCurrency: loyaltyPtsPerCurrency,
        currencyPerPoint: currencyPerPt,
      );

      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Shop Details'),
        ),
        body: BlocConsumer<ShopBloc, ShopState>(
          listener: (context, state) {
            if (state is ShopLoaded) {
              _updateControllers(state.shop);
            } else if (state is ShopOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Shop details saved!'),
                  backgroundColor: Colors.green));
              context.pop();
            } else if (state is ShopError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          buildWhen: (previous, current) =>
              current is ShopLoading || current is ShopLoaded,
          builder: (context, state) {
            if (state is ShopLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Center(
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey[300]!,
                                style: BorderStyle.solid),
                          ),
                          child: _logoPath != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: _logoPath!.startsWith('data:') ||
                                              _logoPath!.startsWith('http')
                                          ? Image.network(_logoPath!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover)
                                          : Image.file(File(_logoPath!),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _logoPath = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withAlpha(120),
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
                                    Text('Shop Logo',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('General Information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                        )),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      'These details will appear on your digital and printed receipts.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    _label('Shop Name'),
                    _compactField(
                      controller: _nameController,
                      hint: 'e.g. QuickMart Superstore',
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    _label('Address Line 1'),
                    _compactField(
                      controller: _address1Controller,
                      hint: 'Samrajpet, Mecheri',
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    _label('Address Line 2 (Optional)'),
                    _compactField(
                      controller: _address2Controller,
                      hint: 'Salem - 636453',
                    ),
                    const SizedBox(height: 15),
                    _label('Phone Number'),
                    _compactField(
                      controller: _phoneController,
                      hint: AppConstants.defaultPhoneHint,
                      keyboardType: TextInputType.phone,
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    _label('M-Pesa Till Number'),
                    _compactField(
                      controller: _mpesaController,
                      hint: 'e.g. 123456',
                    ),
                    const SizedBox(height: 15),
                    _label('VAT Rate (%)'),
                    _compactField(
                      controller: _vatRateController,
                      hint: 'e.g. 16',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 15),
                    _label('KRA PIN'),
                    _compactField(
                      controller: _kraPinController,
                      hint: 'e.g. P051234567Z',
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('Receipt Footer Text'),
                        Text('Max 150 chars',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                    _compactField(
                      controller: _footerController,
                      hint: 'Thank you, Visit again!!!',
                      maxLines: 2,
                      maxLength: 60,
                    ),
                    const SizedBox(height: 24),
                    Text('Loyalty Program',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                        )),
                    const SizedBox(height: 5),
                    Text(
                      'Configure how customers earn and redeem loyalty points.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),
                    _label('KES per Point Earned'),
                    _compactField(
                      controller: _loyaltyPointsPerCurrencyController,
                      hint: '10',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),
                    _label('Points Needed for KES 1 Discount'),
                    _compactField(
                      controller: _currencyPerPointController,
                      hint: '100',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  ),
                ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _saveShop,
          icon: Icons.save,
          label: 'Save Details',
        ));
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
    );
  }

  Widget _compactField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
