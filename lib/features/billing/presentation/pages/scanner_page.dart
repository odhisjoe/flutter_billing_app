import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

import '../bloc/billing_bloc.dart';

class ScannerPage extends StatefulWidget {
  final bool continuousScan;
  const ScannerPage({super.key, this.continuousScan = false});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  int _scanCount = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      final now = DateTime.now();
      if (rawValue == _lastScannedBarcode &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!) < const Duration(milliseconds: 400)) {
        continue;
      }

      _lastScannedBarcode = rawValue;
      _lastScanTime = now;
      _scanCount++;

      Vibration.hasVibrator().then((has) {
        if (has == true) Vibration.vibrate();
      });

      if (mounted) {
        if (widget.continuousScan) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
          setState(() {});
        } else {
          context.pop(rawValue);
        }
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.continuousScan
              ? 'Scanning... ($_scanCount)'
              : 'Scan Barcode',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          Container(
            decoration: const BoxDecoration(),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = (constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight) *
                      0.6;
                  return Container(
                    width: size.clamp(200, 400),
                    height: size.clamp(200, 400),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 48, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(
                          widget.continuousScan ? 'Tap back to stop' : 'Align barcode here',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.continuousScan && _scanCount > 0)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_scanCount scanned',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
