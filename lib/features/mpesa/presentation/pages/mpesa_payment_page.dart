import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/mpesa_bloc.dart';

class MpesaPaymentPage extends StatefulWidget {
  final double amount;
  final String saleId;
  final VoidCallback onPaid;
  final VoidCallback onCancel;

  const MpesaPaymentPage({
    super.key,
    required this.amount,
    required this.saleId,
    required this.onPaid,
    required this.onCancel,
  });

  @override
  State<MpesaPaymentPage> createState() => _MpesaPaymentPageState();
}

class _MpesaPaymentPageState extends State<MpesaPaymentPage> {
  final _phoneCtrl = TextEditingController();
  Timer? _pollTimer;
  int _pollAttempts = 0;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startPayment() {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone: 2547XXXXXXXX'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<MpesaBloc>().add(InitiateStkPush(
      phone: phone,
      amount: widget.amount,
      reference: widget.saleId,
    ));
  }

  void _startPolling(String checkoutRequestId) {
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > 40) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment timed out. You can retry.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      context.read<MpesaBloc>().add(CheckPaymentStatus(checkoutRequestId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MpesaBloc, MpesaState>(
      listener: (context, state) {
        if (state.paymentStatus == 'sent' && state.checkoutRequestId != null) {
          _startPolling(state.checkoutRequestId!);
        }
        if (state.paymentStatus == 'paid') {
          _pollTimer?.cancel();
          widget.onPaid();
        }
        if (state.paymentStatus == 'failed' && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
        if (state.paymentStatus == 'checking' || state.paymentStatus == 'paid') {
          return;
        }
      },
      builder: (context, state) {
        final isIdle = state.paymentStatus == 'idle';
        final isSending = state.paymentStatus == 'sending';
        final isSent = state.paymentStatus == 'sent' || state.paymentStatus == 'checking';
        final isPaid = state.paymentStatus == 'paid';
        final isFailed = state.paymentStatus == 'failed';

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_android, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('M-Pesa STK Push',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isIdle || isFailed)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (isIdle || isFailed) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Customer Phone Number',
                    hintText: '2547XXXXXXXX',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_to_mobile),
                    label: const Text('Send STK Push'),
                    onPressed: _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (isFailed) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ],

              if (isSending) ...[
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 16),
                const Text('Initiating payment...',
                    style: TextStyle(fontSize: 16)),
              ],

              if (isSent) ...[
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 16),
                const Text('STK Push sent!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Check ${_phoneCtrl.text} to enter PIN',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Waiting for confirmation...',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _pollTimer?.cancel();
                    widget.onCancel();
                  },
                  child: const Text('Cancel Payment',
                      style: TextStyle(color: Colors.red)),
                ),
              ],

              if (isPaid) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 12),
                const Text('Payment Successful!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                if (state.mpesaRef != null) ...[
                  const SizedBox(height: 8),
                  Text('M-Pesa Ref: ${state.mpesaRef}',
                      style: const TextStyle(fontSize: 15)),
                ],
                const SizedBox(height: 16),
                Text(
                  'Sale #${widget.saleId.length > 8 ? widget.saleId.substring(0, 8) : widget.saleId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
