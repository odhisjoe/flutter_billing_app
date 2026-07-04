import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/services/device_linking_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/theme/app_theme.dart';

class LinkToShopPage extends StatefulWidget {
  const LinkToShopPage({super.key});

  @override
  State<LinkToShopPage> createState() => _LinkToShopPageState();
}

class _LinkToShopPageState extends State<LinkToShopPage> {
  final _codeCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController(text: '');
  final _service = DeviceLinkingService();
  StreamSubscription? _watchSub;
  bool _loading = false;
  String? _error;
  String? _linkingCode;
  String? _statusMessage;
  bool _showScanner = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _deviceNameCtrl.dispose();
    _watchSub?.cancel();
    super.dispose();
  }

  Future<void> _startLinking(String code) async {
    setState(() {
      _error = null;
      _loading = true;
      _linkingCode = code.toUpperCase().trim();
    });

    try {
      final info = await _service.getLinkingCode(_linkingCode!);
      if (info == null) {
        setState(() {
          _error = 'Invalid linking code. Check and try again.';
          _loading = false;
        });
        return;
      }

      if (info.isExpired) {
        setState(() {
          _error = 'This linking code has expired. Ask the admin to generate a new one.';
          _loading = false;
        });
        return;
      }

      if (!info.isPending) {
        setState(() {
          _error = 'This code has already been used.';
          _loading = false;
        });
        return;
      }

      String deviceName = _deviceNameCtrl.text.trim();
      if (deviceName.isEmpty) {
        deviceName = 'Device ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      }

      await _service.signInAnonymously();

      final submitted = await _service.submitLinkingRequest(_linkingCode!, deviceName);
      if (!submitted) {
        setState(() {
          _error = 'Failed to submit linking request. Try again.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Request sent! Waiting for admin approval...';
        _loading = false;
      });

      _watchSub = _service.watchLinkingCode(_linkingCode!).listen((info) async {
        if (!mounted || info == null) return;
        if (info.isApproved) {
          _watchSub?.cancel();
          setState(() => _statusMessage = 'Approved! Syncing data...');
          await _syncData();
        } else if (info.status == 'rejected') {
          _watchSub?.cancel();
          if (mounted) {
            setState(() => _statusMessage = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Linking request was rejected by admin'),
                backgroundColor: Colors.orange,
              ),
            );
            context.pop();
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _syncData() async {
    try {
      final syncService = di.sl<SyncService>();
      final firebaseSync = syncService;

      // Retry pullAll a few times since Firestore rules need to propagate
      for (int i = 0; i < 5; i++) {
        try {
          await firebaseSync.pullAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shop linked successfully! Data synced.'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/login');
          }
          return;
        } catch (_) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linked but sync may take a moment'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/login');
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      String code = raw;
      if (code.startsWith('pos-link://')) {
        code = code.substring('pos-link://'.length);
      }

      setState(() => _showScanner = false);
      _codeCtrl.text = code;
      _startLinking(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showScanner ? 'Scan QR Code' : 'Link to Shop'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
      ),
      body: _showScanner ? _buildScanner() : _buildForm(),
    );
  }

  Widget _buildScanner() {
    return MobileScanner(
      controller: MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        returnImage: false,
      ),
      onDetect: _onBarcodeDetected,
    );
  }

  Widget _buildForm() {
    if (_statusMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_statusMessage!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.link, size: 48, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          const Text('Link to Shop',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Scan the QR code from the admin\'s "Link Devices" page\nor enter the code manually.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Point camera at QR code',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showScanner = true),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Open Scanner'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or enter code', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _deviceNameCtrl,
            decoration: InputDecoration(
              hintText: 'Device name (e.g. POS-2, Back Office)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[800], fontSize: 13))),
                ],
              ),
            ),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _startLinking(_codeCtrl.text),
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.link),
              label: Text(_loading ? 'Linking...' : 'Link to Shop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
