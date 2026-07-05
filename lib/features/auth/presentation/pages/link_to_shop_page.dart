import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/services/api_device_linking_service.dart';
import '../../../../core/services/api_config_service.dart';
import '../../../../core/services/api_sync_service.dart';
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
  final _serverUrlCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _recoveryPinCtrl = TextEditingController();
  final _service = ApiDeviceLinkingService();
  bool _loading = false;
  String? _error;
  String? _statusMessage;
  bool _showScanner = false;
  bool _showRecoveryForm = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final config = di.sl<ApiConfigService>();
    final url = await config.getServerUrl();
    if (url.isNotEmpty && mounted) {
      _serverUrlCtrl.text = url;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _deviceNameCtrl.dispose();
    _serverUrlCtrl.dispose();
    _shopNameCtrl.dispose();
    _recoveryPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _startLinking(String code) async {
    setState(() {
      _error = null;
      _loading = true;
      _statusMessage = null;
    });

    try {
      final serverUrl = _serverUrlCtrl.text.trim();
      if (serverUrl.isEmpty) {
        setState(() {
          _error = 'Enter the server URL first';
          _loading = false;
        });
        return;
      }

      final config = di.sl<ApiConfigService>();
      await config.saveServerUrl(serverUrl);

      final result = await _service.redeemSession(
        code.toUpperCase().trim(),
        _deviceNameCtrl.text.trim(),
      );

      if (result == null) {
        setState(() {
          _error = 'Could not reach server. Check the URL and try again.';
          _loading = false;
        });
        return;
      }

      if (result.containsKey('error')) {
        setState(() {
          _error = result['error'] as String?;
          _loading = false;
        });
        return;
      }

      final jwt = result['token'] as String?;
      final tenantId = result['tenantId'] as String?;

      if (jwt == null || tenantId == null) {
        setState(() {
          _error = 'Invalid server response';
          _loading = false;
        });
        return;
      }

      await config.saveJwtToken(jwt);
      await config.saveTenantId(tenantId);
      if (result['deviceId'] != null) {
        await config.saveDeviceId(result['deviceId'] as String);
      }

      setState(() => _statusMessage = 'Linked! Syncing data...');

      final syncService = di.sl<SyncService>();
      if (syncService is ApiSyncService) {
        await syncService.signInWithJwt(jwt, tenantId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop linked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _redeemRecoveryPin() async {
    setState(() {
      _error = null;
      _loading = true;
      _statusMessage = null;
    });

    try {
      final serverUrl = _serverUrlCtrl.text.trim();
      if (serverUrl.isEmpty) {
        setState(() { _error = 'Enter the server URL first'; _loading = false; });
        return;
      }

      final shopName = _shopNameCtrl.text.trim();
      final recoveryPin = _recoveryPinCtrl.text.trim().toUpperCase();
      if (shopName.isEmpty || recoveryPin.isEmpty) {
        setState(() { _error = 'Enter both shop name and recovery PIN'; _loading = false; });
        return;
      }

      final config = di.sl<ApiConfigService>();
      await config.saveServerUrl(serverUrl);

      final result = await _service.redeemRecoveryPin(
        shopName: shopName,
        recoveryPin: recoveryPin,
        deviceName: _deviceNameCtrl.text.trim(),
      );

      if (result == null) {
        setState(() { _error = 'Could not reach server. Check the URL and try again.'; _loading = false; });
        return;
      }

      if (result.containsKey('error')) {
        setState(() { _error = result['error'] as String?; _loading = false; });
        return;
      }

      final jwt = result['token'] as String;
      final tenantId = result['tenantId'] as String;

      await config.saveJwtToken(jwt);
      await config.saveTenantId(tenantId);
      if (result['deviceId'] != null) {
        await config.saveDeviceId(result['deviceId'] as String);
      }

      setState(() => _statusMessage = 'Recovered! Syncing data...');

      final syncService = di.sl<SyncService>();
      if (syncService is ApiSyncService) {
        await syncService.signInWithJwt(jwt, tenantId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop recovered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      setState(() { _error = 'Recovery failed: $e'; _loading = false; });
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
          const SizedBox(height: 24),

          TextFormField(
            controller: _serverUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://your-app.onrender.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 140,
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

          // --- Recovery PIN section ---
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (!_showRecoveryForm)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showRecoveryForm = true),
                icon: const Icon(Icons.security, size: 16, color: Colors.orange),
                label: Text(
                  'Lost all devices? Use recovery PIN',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text('Recovery PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange[800])),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showRecoveryForm = false),
                        child: Icon(Icons.close, size: 16, color: Colors.orange[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Shop Name',
                      hintText: 'e.g. Elite Groceries',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _recoveryPinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.bold),
                    inputFormatters: [UpperCaseTextFormatter()],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _redeemRecoveryPin,
                      icon: _loading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.restore, size: 14),
                      label: Text(_loading ? 'Recovering...' : 'Recover Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
