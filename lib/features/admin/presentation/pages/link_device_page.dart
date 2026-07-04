import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../core/services/device_linking_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/theme/app_theme.dart';

class LinkDevicePage extends StatefulWidget {
  const LinkDevicePage({super.key});

  @override
  State<LinkDevicePage> createState() => _LinkDevicePageState();
}

class _LinkDevicePageState extends State<LinkDevicePage> {
  final _service = DeviceLinkingService();
  String? _currentCode;
  LinkingCodeInfo? _currentInfo;
  StreamSubscription? _watchSub;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentCode = null;
      _currentInfo = null;
    });
    _watchSub?.cancel();

    try {
      final syncService = di.sl<SyncService>();
      if (!syncService.isSignedIn) {
        setState(() {
          _error = 'Cloud Sync not connected. Go to Settings > Cloud Sync first.';
          _loading = false;
        });
        return;
      }

      final tenantId = await _findTenantId();
      if (tenantId == null) {
        setState(() {
          _error = 'Tenant not found. Ensure cloud sync is set up.';
          _loading = false;
        });
        return;
      }

      final code = await _service.generateLinkingCode(tenantId);
      _currentCode = code;

      _watchSub = _service.watchLinkingCode(code).listen((info) {
        if (!mounted) return;
        setState(() => _currentInfo = info);
        if (info?.isLinked == true) {
          _showApprovalDialog(info!);
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to generate code: $e';
        _loading = false;
      });
    }
  }

  Future<String?> _findTenantId() async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final tenants =
          await db.collection('tenants').where('ownerAdminUid', isEqualTo: uid).limit(1).get();
      if (tenants.docs.isNotEmpty) return tenants.docs.first.id;

      final adminDocs = await db.collectionGroup('admins')
          .where('ownerAdminUid', isEqualTo: uid).limit(1).get();
      if (adminDocs.docs.isNotEmpty) {
        final ref = adminDocs.docs.first.reference;
        return ref.parent.parent?.id;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showApprovalDialog(LinkingCodeInfo info) async {
    final approve = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Wants to Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(info.deviceName ?? 'Unknown device',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('A new device is requesting to link to this shop.'),
            const SizedBox(height: 8),
            const Text('Granting access will allow this device to read all shop data.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (approve == null || !mounted) return;

    if (approve) {
      final success = await _service.approveLinking(info.code, isAdmin: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Device linked successfully!' : 'Failed to approve device'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _currentCode = null;
          _currentInfo = null;
          _watchSub?.cancel();
          setState(() {});
        }
      }
    } else {
      await _service.rejectLinking(info.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linking request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _currentCode = null;
        _currentInfo = null;
        _watchSub?.cancel();
        setState(() {});
      }
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
    final info = _currentInfo;
    final expiresIn = info != null
        ? info.expiresAt.difference(DateTime.now())
        : const Duration(hours: 24);

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
                // ignore: deprecated_member_use
                PrettyQr(
                  data: 'pos-link://$_currentCode',
                  size: 200,
                  elementColor: Colors.black87,
                  roundEdges: true,
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
          const SizedBox(height: 16),
          Text(
            'Expires in ${expiresIn.inHours}h ${expiresIn.inMinutes.remainder(60)}m',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          if (info?.isLinked == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text('Waiting for your approval...',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 16),
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
