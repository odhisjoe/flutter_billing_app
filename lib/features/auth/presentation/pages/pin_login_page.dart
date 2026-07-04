import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/user.dart';
import '../../data/models/user_model.dart';
import '../bloc/auth_bloc.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  User? _selectedUser;
  bool _error = false;
  bool _loading = false;
  UserRole _selectedRole = UserRole.admin;
  int _versionTapCount = 0;
  DateTime? _lastVersionTap;

  List<UserModel> get _users {
    final all = HiveDatabase.usersBox.values.where((u) => u.isActive).toList();
    return all;
  }

  List<UserModel> get _filteredUsers =>
      _users.where((u) => u.role == _selectedRole).toList();

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _pin = '';
      _error = false;
    });
  }

  void _onKey(String key) {
    if (_pin.length >= 4 || _loading) return;
    setState(() {
      _pin += key;
      _error = false;
    });
    if (_pin.length >= 4) _submit();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_selectedUser == null) return;
    setState(() => _loading = true);
    final user = _selectedUser!;
    context.read<AuthBloc>().add(LoginEvent(pin: _pin, role: user.role));
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTap != null && now.difference(_lastVersionTap!) > const Duration(seconds: 2)) {
      _versionTapCount = 0;
    }
    _lastVersionTap = now;
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _showHiddenSuperAdminLogin();
    }
  }

  void _showHiddenSuperAdminLogin() {
    final superUsers = HiveDatabase.usersBox.values
        .where((u) => u.role == UserRole.superAdmin && u.isActive)
        .toList();
    if (superUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No super admin account found')),
      );
      return;
    }
    final superUser = superUsers.first;
    String enteredPin = '';
    bool error = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Verify'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < enteredPin.length ? Colors.red : Colors.grey[300],
                    ),
                  )),
                ),
                if (error) ...[
                  const SizedBox(height: 8),
                  const Text('Incorrect PIN', style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in ['1','2','3','4','5','6','7','8','9','','0'])
                      k.isEmpty
                          ? const SizedBox(width: 56)
                          : SizedBox(
                              width: 56,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (enteredPin.length >= 4) return;
                                  setDialogState(() {
                                    enteredPin += k;
                                    error = false;
                                  });
                                  if (enteredPin.length == 4) {
                                    if (enteredPin == superUser.pin) {
                                      Navigator.pop(ctx);
                                      context.read<AuthBloc>().add(
                                        LoginEvent(pin: enteredPin, role: UserRole.superAdmin),
                                      );
                                    } else {
                                      setDialogState(() {
                                        enteredPin = '';
                                        error = true;
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[100],
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                              ),
                            ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedUser == null) return _buildUserSelection();
    return _buildPinEntry();
  }

  Widget _buildUserSelection() {
    final users = _filteredUsers;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.push('/operations-pin'),
                  child: Icon(Icons.point_of_sale, size: 40, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16),
                const Text('Who\'s using the POS?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _roleTab('Admin', UserRole.admin, Colors.purple),
                      const SizedBox(width: 4),
                      _roleTab('Cashier', UserRole.cashier, Colors.teal),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (users.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text('No ${_selectedRole.name} users found.'),
                  )
                else
                  ...users.map((u) => _userTile(u)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/download'),
                      icon: Icon(Icons.android, size: 16, color: Colors.grey[400]),
                      label: Text('Get Android App',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/download-windows'),
                      icon: Icon(Icons.window, size: 16, color: Colors.grey[400]),
                      label: Text('Get Windows App',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push('/link-to-shop'),
                  icon: Icon(Icons.link, size: 14, color: Colors.grey[350]),
                  label: Text('Link to Existing Shop',
                      style: TextStyle(fontSize: 12, color: Colors.grey[350])),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _onVersionTap,
                  child: Text('v1.0.0', style: TextStyle(fontSize: 11, color: Colors.grey[300])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleTab(String label, UserRole role, Color color) {
    final active = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: active ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _userTile(UserModel user) {
    final color = user.role == UserRole.admin ? Colors.purple : Colors.teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectUser(user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(user.name[0].toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(user.role == UserRole.admin ? 'Administrator' : 'Cashier',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          if (state.needsPinChange == true) {
            context.go('/set-pin');
          } else if (state.user!.isSuperAdmin) {
            context.go('/super-admin');
          } else {
            context.go(state.user!.role == UserRole.admin ? '/admin' : '/');
          }
        } else if (state.status == AuthStatus.unauthenticated && state.message != null) {
          setState(() {
            _pin = '';
            _error = true;
            _loading = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: (_selectedUser!.role == UserRole.admin
                        ? Colors.purple : Colors.teal).withValues(alpha: 0.12),
                    child: Text(_selectedUser!.name[0].toUpperCase(),
                        style: TextStyle(
                          color: _selectedUser!.role == UserRole.admin
                              ? Colors.purple : Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        )),
                  ),
                  const SizedBox(height: 12),
                  Text(_selectedUser!.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedUser = null),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Switch user', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? (_selectedUser!.role == UserRole.admin
                                ? Colors.purple : Colors.teal)
                            : Colors.grey[300],
                      ),
                    )),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 12),
                    const Text('Incorrect PIN. Try again.',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  else
                    _buildPinPad(),
                ],
              ),
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
