import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/bloc/sync_status_cubit.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/sync_status.dart';

class FirebaseLinkPage extends StatefulWidget {
  const FirebaseLinkPage({super.key});

  @override
  State<FirebaseLinkPage> createState() => _FirebaseLinkPageState();
}

class _FirebaseLinkPageState extends State<FirebaseLinkPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: BlocConsumer<SyncStatusCubit, SyncStatus>(
          listener: _onSyncStatusChanged,
          builder: (context, status) {
            final syncService = di.sl<SyncService>();
            if (syncService.isSignedIn) {
              return _buildSignedIn(context, syncService);
            }
            return _buildSignInForm();
          },
        ),
      ),
    );
  }

  void _onSyncStatusChanged(BuildContext context, SyncStatus status) {
    final messenger = ScaffoldMessenger.of(context);
    if (status == SyncStatus.connected) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Connected to cloud'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      context.pop();
    } else if (status == SyncStatus.syncing) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Syncing data...'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    } else if (status == SyncStatus.error && !_loading) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Sync error occurred'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildSignedIn(BuildContext context, SyncService syncService) {
    final lastBackup = syncService.lastBackupTime;
    final timeAgo = lastBackup != null
        ? _formatTimeAgo(DateTime.now().difference(lastBackup))
        : 'Never';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_done, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Cloud Sync Active',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
        const SizedBox(height: 8),
        Text('Auto-backup every hour',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          'Last backup: $timeAgo',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDisconnect(context, syncService),
            icon: const Icon(Icons.cloud_off, color: Colors.red),
            label: const Text('Disconnect Cloud Sync'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildSignInForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Link to Firebase Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your Firebase account to enable\ncloud sync across devices.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter email';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter password';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSignIn,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleCreateAccount,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Create Account on Firebase'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await di.sl<SyncService>().signIn(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
    } on auth.FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message ?? 'Authentication failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCreateAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Firebase Account'),
        content: const Text(
          'You will be taken to the Firebase Console to add a new user.\n\n'
          'After creating the account, return here and sign in with the credentials you set.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Firebase Console'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final uri = Uri.parse('https://console.firebase.google.com/project/tikach-pos/authentication/users');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _confirmDisconnect(
      BuildContext context, SyncService syncService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Cloud Sync?'),
        content: const Text(
          'Data will remain on your device, but will no longer sync to the cloud.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await syncService.signOut();
    }
  }
}
