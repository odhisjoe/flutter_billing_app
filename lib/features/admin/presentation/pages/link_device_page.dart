import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../core/services/api_device_linking_service.dart';
import '../../../../core/services/api_config_service.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/theme/app_theme.dart';

class LinkDevicePage extends StatefulWidget {
  const LinkDevicePage({super.key});

  @override
  State<LinkDevicePage> createState() => _LinkDevicePageState();
}

class _LinkDevicePageState extends State<LinkDevicePage> {
  final _service = ApiDeviceLinkingService();
  String? _currentCode;
  String? _currentPin;
  bool _loading = false;
  String? _error;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _loadTenantId();
  }

  Future<void> _loadTenantId() async {
    final config = di.sl<ApiConfigService>();
    final tenantId = await config.getTenantId();
    if (mounted) setState(() => _tenantId = tenantId);
  }

  Future<void> _generateCode() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentCode = null;
      _currentPin = null;
    });

    try {
      if (_tenantId == null) {
        setState(() {
          _error = 'Tenant ID not found. Ensure cloud sync is connected.';
          _loading = false;
        });
        return;
      }

      final info = await _service.createSession(_tenantId!);
      if (info == null) {
        setState(() {
          _error = 'Failed to generate pairing code. Check server connection.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _currentCode = info.code;
        _currentPin = info.pin;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate code: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Devices'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: Colors.red[800], fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: Icon(Icons.close, size: 16, color: Colors.red[400]),
                    ),
                  ],
                ),
              ),

            if (_currentCode != null) ...[
              _buildCodeDisplay(),
            ] else ...[
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCodeDisplay() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.link, size: 28, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          const Text('Share this code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Scan with the new device to link it to this shop',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 200,
                  child: PrettyQrView.data(
                    data: 'pos-link://$_currentCode',
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: Colors.black87,
                        roundFactor: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _currentCode!,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                  ),
                ),
              ],
            ),
          ),
          if (_currentPin != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Text('Fallback PIN', style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _currentPin!,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Code expires in 5 minutes',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loading ? null : _generateCode,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Link a New Device',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Generate a QR code that other devices can scan\nto link with this shop.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generateCode,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.qr_code_2),
              label: Text(_loading ? 'Generating...' : 'Generate Code'),
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
