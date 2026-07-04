import 'dart:async';
import 'dart:io';

import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/database/secondary_db.dart';
import 'package:billing_app/core/utils/app_constants.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';
import 'package:billing_app/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billing_app/features/customer/data/models/customer_model.dart';
import 'package:billing_app/features/customer/domain/entities/customer.dart';
import 'package:billing_app/features/mpesa/presentation/bloc/mpesa_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────
// Payment Modal
// ─────────────────────────────────────────────

Future<PaymentBreakdown?> showPaymentModal(
  BuildContext context,
  double grandTotal,
) {
  return showDialog<PaymentBreakdown>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PaymentModalBody(grandTotal: grandTotal),
  );
}

class _PaymentModalBody extends StatefulWidget {
  final double grandTotal;
  const _PaymentModalBody({required this.grandTotal});

  @override
  State<_PaymentModalBody> createState() => _PaymentModalBodyState();
}

class _PaymentModalBodyState extends State<_PaymentModalBody> {
  final _cashCtrl = TextEditingController();
  final _mpesaCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _stkPhoneCtrl = TextEditingController();
  final _lookupCtrl = TextEditingController();
  List<Map<String, dynamic>> _lookupResults = [];
  bool _lookupSearching = false;
  Customer? _selectedCustomer;

  bool _showStkPush = false;
  String _stkStatus = 'idle';
  String? _stkMpesaRef;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _mpesaCtrl.dispose();
    _cardCtrl.dispose();
    _bankCtrl.dispose();
    _phoneCtrl.dispose();
    _stkPhoneCtrl.dispose();
    _lookupCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _searchCustomer() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final model = HiveDatabase.customerBox.values.cast<CustomerModel?>().firstWhere(
      (m) {
        if (m == null) return false;
        return m.phoneNumber.replaceAll(RegExp(r'\s+'), '') == cleaned;
      },
      orElse: () => null,
    );
    setState(() => _selectedCustomer = model?.toEntity());
  }

  double _val(TextEditingController c) => double.tryParse(c.text) ?? 0;

  double get _paid => _val(_cashCtrl) + _val(_mpesaCtrl) +
      _val(_cardCtrl) + _val(_bankCtrl);

  double get _remaining => widget.grandTotal - _paid;

  double get _change => _remaining < 0 ? _remaining.abs() : 0;

  bool get _isFullyPaid => _paid >= widget.grandTotal && _paid > 0;

  String _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('0')) {
      return '254${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('+')) {
      return cleaned.substring(1);
    }
    if (!cleaned.startsWith('254')) {
      return '254$cleaned';
    }
    return cleaned;
  }

  Future<void> _sendStkPush() async {
    final phone = _stkPhoneCtrl.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone: 07XXXXXXXX or 01XXXXXXXX'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final normalized = _normalizePhone(phone);
    if (normalized.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Kenyan phone number'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final saleId = const Uuid().v4();

    if (!mounted) return;
    final alreadyPaid = await SecondaryDb.isSalePaid(saleId);
    if (alreadyPaid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This transaction was already paid'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _stkStatus = 'sending');
    context.read<MpesaBloc>().add(InitiateStkPush(
      phone: normalized,
      amount: widget.grandTotal,
      reference: saleId,
    ));
  }

  void _startPolling(String checkoutRequestId) {
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > 40) {
        timer.cancel();
        if (mounted) {
          setState(() => _stkStatus = 'timeout');
        }
        return;
      }
      context.read<MpesaBloc>().add(CheckPaymentStatus(checkoutRequestId));
    });
  }

  Future<void> _searchLookup() async {
    final query = _lookupCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _lookupSearching = true);
    final results = await SecondaryDb.searchMpesaPayments(query);
    if (mounted) {
      setState(() {
        _lookupResults = results;
        _lookupSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxW = screenW < 600 ? screenW * 0.95 : 400.0;
    return Dialog(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: screenH * 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ──
            Row(
              children: [
                const Icon(Icons.payments, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 6),
                const Text('Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Customer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: _selectedCustomer != null
                  ? Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${_selectedCustomer!.name} | ${_selectedCustomer!.loyaltyPoints} pts',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedCustomer = null),
                          child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Customer phone',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 11),
                            onSubmitted: (_) => _searchCustomer(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _searchCustomer,
                          child: const Icon(Icons.search, size: 14, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),

            // ── Total ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Total Due', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  Text(AppConstants.formatPrice(widget.grandTotal),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Amount Fields (2×2 grid) ──
            _amountField('Cash', Icons.payments, _cashCtrl),
            const SizedBox(height: 6),
            _amountField('M-Pesa', Icons.phone_android, _mpesaCtrl),
            const SizedBox(height: 6),
            _amountField('Card', Icons.credit_card, _cardCtrl),
            const SizedBox(height: 6),
            _amountField('Bank', Icons.account_balance, _bankCtrl),
            const SizedBox(height: 8),

            // ── STK Push ──
            if (_stkStatus == 'paid')
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('STK Push paid${_stkMpesaRef != null ? " - Ref: $_stkMpesaRef" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.green)),
                  ),
                ],
              )
            else if (!_showStkPush)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showStkPush = true);
                    context.read<MpesaBloc>().add(ResetMpesaStatus());
                  },
                  icon: const Icon(Icons.phone_android, size: 12, color: Colors.green),
                  label: const Text('STK Push', style: TextStyle(fontSize: 11, color: Colors.green)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 6)),
                ),
              ),

            if ((_showStkPush || _stkStatus != 'idle') && _stkStatus != 'paid')
              BlocListener<MpesaBloc, MpesaState>(
                listenWhen: (prev, curr) => prev.paymentStatus != curr.paymentStatus || curr.paymentStatus == 'paid',
                listener: (context, state) {
                  if (state.paymentStatus == 'sent' && state.checkoutRequestId != null) {
                    setState(() => _stkStatus = 'sent');
                    _startPolling(state.checkoutRequestId!);
                  }
                  if (state.paymentStatus == 'paid') {
                    _pollTimer?.cancel();
                    setState(() { _stkStatus = 'paid'; _stkMpesaRef = state.mpesaRef; _mpesaCtrl.text = widget.grandTotal.toStringAsFixed(2); });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('M-Pesa confirmed! Ref: ${state.mpesaRef ?? "N/A"}'),
                      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                    ));
                  }
                  if (state.paymentStatus == 'failed' && state.error != null) {
                    _pollTimer?.cancel();
                    setState(() => _stkStatus = 'failed');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('STK Push failed: ${state.error}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
                  child: Column(
                    children: [
                      if (_stkStatus == 'idle' || _stkStatus == 'failed' || _stkStatus == 'timeout')
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _stkPhoneCtrl,
                                decoration: const InputDecoration(hintText: '07XX or 01XX', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                onPressed: _sendStkPush,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                child: Text(_stkStatus == 'timeout' ? 'Retry' : 'Send', style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                            if (_showStkPush)
                              IconButton(
                                icon: const Icon(Icons.close, size: 14),
                                onPressed: () => setState(() { _showStkPush = false; _stkStatus = 'idle'; }),
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      if (_stkStatus == 'sending' || _stkStatus == 'sent')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 6),
                            Text(_stkStatus == 'sending' ? 'Sending...' : 'Enter PIN on phone', style: const TextStyle(fontSize: 11)),
                            if (_stkStatus == 'sent')
                              TextButton(
                                onPressed: () { _pollTimer?.cancel(); setState(() { _stkStatus = 'idle'; _showStkPush = false; }); },
                                child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 10)),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // ── Lookup ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lookupCtrl,
                    decoration: const InputDecoration(hintText: 'Lookup M-Pesa ref', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    style: const TextStyle(fontSize: 11),
                    onSubmitted: (_) => _searchLookup(),
                  ),
                ),
                GestureDetector(
                  onTap: _lookupSearching ? null : _searchLookup,
                  child: _lookupSearching
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.search, size: 14, color: Colors.grey[500]),
                ),
              ],
            ),
            if (_lookupResults.isNotEmpty)
              ..._lookupResults.take(2).map((r) {
                final paid = r['paid'] == 1;
                final ref = r['mpesa_ref'] as String? ?? '—';
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(paid ? Icons.check_circle : Icons.access_time, size: 11, color: paid ? Colors.green : Colors.grey),
                      const SizedBox(width: 4),
                      Text(paid ? 'Paid - $ref' : 'Pending', style: TextStyle(fontSize: 10, color: paid ? Colors.green[800] : Colors.grey[600])),
                    ],
                  ),
                );
              }),

            const Spacer(),

            // ── Summary ──
            Divider(color: Colors.grey[200], height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paid', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(AppConstants.formatPrice(_paid), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (_remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.orange[700])),
                    Text(AppConstants.formatPrice(_remaining), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                  ],
                ),
              ),
            if (_change > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Change', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                    Text(AppConstants.formatPrice(_change), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[700])),
                  ],
                ),
              ),

            // ── Button ──
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _isFullyPaid
                    ? () => Navigator.pop(context, PaymentBreakdown(
                        cash: _val(_cashCtrl), mpesa: _val(_mpesaCtrl), card: _val(_cardCtrl), bank: _val(_bankCtrl),
                        change: _change, grandTotal: widget.grandTotal,
                        customerId: _selectedCustomer?.id, customerName: _selectedCustomer?.name,
                      ))
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Review Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField(String label, IconData icon, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Row(
            children: [
              Icon(icon, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              prefixText: 'KES ',
              prefixStyle: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Receipt Preview Modal
// ─────────────────────────────────────────────

Future<bool?> showReceiptPreview(
  BuildContext context, {
  required String shopName,
  required String address1,
  required String address2,
  required String phone,
  required String kraPin,
  required double vatRate,
  required double vatAmount,
  required String footer,
  required List<CartItem> cartItems,
  required PaymentBreakdown payment,
  String? logoUrl,
  String? cashierName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReceiptPreviewBody(
      shopName: shopName,
      address1: address1,
      address2: address2,
      phone: phone,
      kraPin: kraPin,
      vatRate: vatRate,
      vatAmount: vatAmount,
      footer: footer,
      cartItems: cartItems,
      payment: payment,
      logoUrl: logoUrl,
      cashierName: cashierName,
    ),
  );
}

class _ReceiptPreviewBody extends StatefulWidget {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String kraPin;
  final double vatRate;
  final double vatAmount;
  final String footer;
  final List<CartItem> cartItems;
  final PaymentBreakdown payment;
  final String? logoUrl;
  final String? cashierName;

  const _ReceiptPreviewBody({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.kraPin,
    required this.vatRate,
    required this.vatAmount,
    required this.footer,
    required this.cartItems,
    required this.payment,
    this.logoUrl,
    this.cashierName,
  });

  @override
  State<_ReceiptPreviewBody> createState() => _ReceiptPreviewBodyState();
}

class _ReceiptPreviewBodyState extends State<_ReceiptPreviewBody> {
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _startAutoPrint();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startAutoPrint() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        if (mounted) Navigator.pop(context, true);
        return false;
      }
      return true;
    });
  }

  String get _totalAmount =>
      widget.cartItems.fold(0.0, (s, i) => s + i.total).toStringAsFixed(2);
  String get _grandTotal =>
      (double.parse(_totalAmount) + widget.vatAmount).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxW = screenWidth < 600 ? screenWidth * 0.95 : 420.0;
    return Dialog(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: 580),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Receipt Preview',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Receipt card
            Flexible(
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SingleChildScrollView(
                child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 36, height: 36,
                            child: widget.logoUrl!.startsWith('data:') ||
                                    widget.logoUrl!.startsWith('http')
                                ? Image.network(widget.logoUrl!, fit: BoxFit.cover)
                                : Image.file(File(widget.logoUrl!), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(widget.shopName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  if (widget.address1.isNotEmpty)
                    Text(widget.address1,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                  if (widget.address2.isNotEmpty)
                    Text(widget.address2,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                  Text(widget.phone,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                  if (widget.kraPin.isNotEmpty)
                    Text('KRA PIN: ${widget.kraPin}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                      DateFormat('dd-MM-yyyy hh:mm a')
                          .format(DateTime.now()),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500])),
                  if (widget.cashierName != null)
                    Text('Served by: ${widget.cashierName}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500])),
                  Divider(color: Colors.grey[300]),
                  // Items
                  ...widget.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${item.quantity}x ${item.product.name}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                AppConstants.formatPrice(item.total),
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      )),
                  Divider(color: Colors.grey[300]),
                  if (widget.vatRate > 0)
                    _receiptRow('Subtotal',
                        AppConstants.formatPrice(double.parse(_totalAmount)),
                        false),
                  if (widget.vatRate > 0)
                    _receiptRow(
                        'VAT (${widget.vatRate}%)',
                        AppConstants.formatPrice(widget.vatAmount),
                        false),
                  _receiptRow('Total', AppConstants.formatPrice(double.parse(_grandTotal)), true),
                  Divider(color: Colors.grey[300]),
                  const Text('Payment',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  if (widget.payment.cash > 0)
                    _receiptRow('Cash',
                        AppConstants.formatPrice(widget.payment.cash), false),
                  if (widget.payment.mpesa > 0)
                    _receiptRow('M-Pesa',
                        AppConstants.formatPrice(widget.payment.mpesa), false),
                  if (widget.payment.card > 0)
                    _receiptRow('Card',
                        AppConstants.formatPrice(widget.payment.card), false),
                  if (widget.payment.bank > 0)
                    _receiptRow('Bank',
                        AppConstants.formatPrice(widget.payment.bank), false),
                  if (widget.payment.change > 0)
                    _receiptRow('Change',
                        AppConstants.formatPrice(widget.payment.change), false),
                  const SizedBox(height: 8),
                  if (widget.footer.isNotEmpty)
                    Text(widget.footer,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                ],
                ),
              ),
            ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Edit Payment',
                        style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    label: Text('Printing in $_countdown...',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, bool isTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 13 : 11,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: Colors.grey[700])),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal ? AppTheme.primaryColor : Colors.black87)),
        ],
      ),
    );
  }
}
