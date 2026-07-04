import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/mpesa_bloc.dart';
import '../../data/mpesa_repository_impl.dart';

Future<void> showMpesaConfigModal(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: context.read<MpesaBloc>(),
      child: const _MpesaConfigModal(),
    ),
  );
}

class _MpesaConfigModal extends StatefulWidget {
  const _MpesaConfigModal();

  @override
  State<_MpesaConfigModal> createState() => _MpesaConfigModalState();
}

class _MpesaConfigModalState extends State<_MpesaConfigModal> {
  final _serverUrlCtrl = TextEditingController();
  final _consumerKeyCtrl = TextEditingController();
  final _consumerSecretCtrl = TextEditingController();
  final _passkeyCtrl = TextEditingController();
  bool _isSandbox = true;
  bool _showSecrets = false;

  @override
  void initState() {
    super.initState();
    context.read<MpesaBloc>().add(LoadMpesaConfig());
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _consumerKeyCtrl.dispose();
    _consumerSecretCtrl.dispose();
    _passkeyCtrl.dispose();
    super.dispose();
  }

  void _populateFromConfig(MpesaConfig config) {
    _serverUrlCtrl.text = config.serverUrl;
    _consumerKeyCtrl.text = config.consumerKey;
    _consumerSecretCtrl.text = config.consumerSecret;
    _passkeyCtrl.text = config.passkey;
    _isSandbox = config.isSandbox;
  }

  void _save() {
    context.read<MpesaBloc>().add(SaveMpesaConfig(MpesaConfig(
      serverUrl: _serverUrlCtrl.text.trim(),
      consumerKey: _consumerKeyCtrl.text.trim(),
      consumerSecret: _consumerSecretCtrl.text.trim(),
      passkey: _passkeyCtrl.text.trim(),
      shortcode: '',
      isSandbox: _isSandbox,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxW = screenW < 600 ? screenW * 0.92 : 420.0;
    return Dialog(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: screenH * 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: BlocConsumer<MpesaBloc, MpesaState>(
        listener: (context, state) {
          if (state.success != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.success!), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
            ));
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.error!), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (context, state) {
          if (state.config.serverUrl.isNotEmpty && _serverUrlCtrl.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _populateFromConfig(state.config);
            });
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.green, size: 22),
                    const SizedBox(width: 8),
                    const Text('M-Pesa Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Configure your Daraja API credentials', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: _serverUrlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'https://your-app.onrender.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _consumerKeyCtrl,
                          decoration: InputDecoration(
                            labelText: 'Consumer Key',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _consumerSecretCtrl,
                          obscureText: !_showSecrets,
                          decoration: InputDecoration(
                            labelText: 'Consumer Secret',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            suffixIcon: IconButton(
                              icon: Icon(_showSecrets ? Icons.visibility : Icons.visibility_off, size: 18),
                              onPressed: () => setState(() => _showSecrets = !_showSecrets),
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passkeyCtrl,
                          obscureText: !_showSecrets,
                          decoration: InputDecoration(
                            labelText: 'Passkey',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            suffixIcon: IconButton(
                              icon: Icon(_showSecrets ? Icons.visibility : Icons.visibility_off, size: 18),
                              onPressed: () => setState(() => _showSecrets = !_showSecrets),
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud, size: 16, color: _isSandbox ? Colors.orange : Colors.blue),
                              const SizedBox(width: 8),
                              Text(_isSandbox ? 'Sandbox Environment' : 'Live (Production)',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: _isSandbox ? Colors.orange[800] : Colors.blue[800])),
                              const Spacer(),
                              Switch(
                                value: _isSandbox,
                                onChanged: (v) => setState(() => _isSandbox = v),
                                activeThumbColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSandbox
                              ? 'Using sandbox.safaricom.co.ke for testing'
                              : 'Using api.safaricom.co.ke for PRODUCTION',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: state.testing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering, size: 14),
                        label: const Text('Test', style: TextStyle(fontSize: 12)),
                        onPressed: state.testing ? null : () => context.read<MpesaBloc>().add(TestMpesaConnection()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: state.loading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 14),
                        label: const Text('Save', style: TextStyle(fontSize: 12)),
                        onPressed: state.loading ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Page wrapper for route-based access (settings page)
class MpesaConfigPage extends StatelessWidget {
  const MpesaConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: _MpesaConfigModal(),
      ),
    );
  }
}
