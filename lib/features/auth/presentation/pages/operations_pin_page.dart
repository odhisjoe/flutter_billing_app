import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';

class OperationsPinPage extends StatefulWidget {
  const OperationsPinPage({super.key});

  @override
  State<OperationsPinPage> createState() => _OperationsPinPageState();
}

class _OperationsPinPageState extends State<OperationsPinPage> {
  static const String _correctPin = '8667';
  String _pin = '';
  bool _error = false;

  void _onKey(String key) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = false;
    });
    if (_pin.length == 4) {
      if (_pin == _correctPin) {
        context.pushReplacement('/super-admin');
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _pin = '';
              _error = true;
            });
          }
        });
      }
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Operations Access',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Enter PIN to view operations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('All platform activities at a glance',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? Colors.indigo : Colors.grey[300],
                    ),
                  )),
                ),
                if (_error) ...[
                  const SizedBox(height: 12),
                  const Text('Incorrect PIN. Try again.',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                _buildPinPad(),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(LogoutEvent());
                  },
                  icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinPad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        return Material(
          color: k == '⌫' ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: k == '⌫' ? _onDelete : () => _onKey(k),
            child: Center(
              child: Text(
                k,
                style: TextStyle(
                  fontSize: k == '⌫' ? 20 : 24,
                  fontWeight: FontWeight.w500,
                  color: k == '⌫' ? Colors.grey[700] : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
