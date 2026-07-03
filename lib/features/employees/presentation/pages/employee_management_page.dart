import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/pin_encryption_service.dart';
import '../../../auth/domain/entities/user.dart';
import '../bloc/employee_bloc.dart';
import '../bloc/employee_event.dart';
import '../bloc/employee_state.dart';

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final Set<String> _visiblePins = {};

  @override
  void initState() {
    super.initState();
    context.read<EmployeeBloc>().add(const LoadEmployees());
  }

  String _generatePin() {
    final rng = Random();
    return List.generate(4, (_) => rng.nextInt(10)).join();
  }

  String _displayPin(String stored) {
    try {
      final service = GetIt.instance<PinEncryptionService>();
      return service.decryptPin(stored);
    } catch (_) {
      return '******';
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: _generatePin());
    UserRole role = UserRole.cashier;
    bool pinVisible = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Employee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Employee full name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: !pinVisible,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(pinVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setDialogState(() => pinVisible = !pinVisible),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            setDialogState(() => pinCtrl.text = _generatePin()),
                        tooltip: 'Generate new PIN',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => role = UserRole.cashier),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: role == UserRole.cashier
                                ? const Color(0xFF6C63FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Cashier',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: role == UserRole.cashier
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => role = UserRole.admin),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: role == UserRole.admin
                                ? const Color(0xFF6C63FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Admin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: role == UserRole.admin
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty && pinCtrl.text.trim().length == 4) {
      if (!mounted) return;
      context.read<EmployeeBloc>().add(AddEmployee(
            name: nameCtrl.text.trim(),
            pin: pinCtrl.text.trim(),
            role: role,
          ));
    }
  }

  Future<void> _showEditDialog(User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final pinCtrl = TextEditingController(text: _displayPin(user.pin));
    UserRole role = user.role;
    bool pinVisible = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Employee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: !pinVisible,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New PIN (leave blank to keep current)',
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(pinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => pinVisible = !pinVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => role = UserRole.cashier),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: role == UserRole.cashier
                                ? const Color(0xFF6C63FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Cashier',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: role == UserRole.cashier
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => role = UserRole.admin),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: role == UserRole.admin
                                ? const Color(0xFF6C63FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Admin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: role == UserRole.admin
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final newPin = pinCtrl.text.trim();
      if (newPin.isNotEmpty && newPin.length != 4) return;
      if (!mounted) return;
      context.read<EmployeeBloc>().add(UpdateEmployee(
            user: User(
              id: user.id,
              name: nameCtrl.text.trim(),
              pin: newPin.isEmpty ? user.pin : newPin,
              role: role,
              isActive: user.isActive,
              hasCompletedSetup: newPin.isEmpty ? user.hasCompletedSetup : false,
              previousPin: user.previousPin,
              isPinReset: user.isPinReset,
            ),
          ));
    }
  }

  Future<void> _confirmDelete(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Remove ${user.name} permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      context.read<EmployeeBloc>().add(DeleteEmployee(userId: user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
      body: BlocConsumer<EmployeeBloc, EmployeeState>(
        listener: (context, state) {
          if (state.status == EmployeeStatus.error && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
            ));
          }
        },
        builder: (context, state) {
          if (state.status == EmployeeStatus.initial ||
              state.status == EmployeeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No employees found',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showAddDialog,
                    child: const Text('Add Employee'),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Use card layout on narrow screens, table on wide screens
              final isWide = constraints.maxWidth >= 640;

              if (isWide) {
                return _buildTableLayout(state);
              }
              return _buildCardLayout(state);
            },
          );
        },
      ),
    );
  }

  // ── Card layout for phones ──────────────────────────────────────────────────
  Widget _buildCardLayout(EmployeeState state) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = state.employees[index];
        final pinVisible = _visiblePins.contains(user.id);
        final isAdmin = user.role == UserRole.admin;
        final roleColor = isAdmin ? const Color(0xFF6C63FF) : Colors.teal;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Avatar + name + role badge + action menu
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAdmin ? 'Admin' : 'Cashier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: user.isActive
                                      ? Colors.green
                                      : Colors.red[300],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: user.isActive
                                      ? Colors.green[700]
                                      : Colors.red[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                      onSelected: (val) {
                        if (val == 'edit') _showEditDialog(user);
                        if (val == 'toggle') {
                          context.read<EmployeeBloc>().add(
                              ToggleEmployeeActive(userId: user.id));
                        }
                        if (val == 'delete') _confirmDelete(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(children: [
                            Icon(
                              user.isActive ? Icons.block : Icons.check_circle,
                              size: 18,
                              color: user.isActive ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(user.isActive ? 'Deactivate' : 'Activate'),
                          ]),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2: PIN display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'PIN: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        pinVisible ? _displayPin(user.pin) : '••••',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (pinVisible) {
                              _visiblePins.remove(user.id);
                            } else {
                              _visiblePins.add(user.id);
                            }
                          });
                        },
                        child: Icon(
                          pinVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Row 3: Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditDialog(user),
                        icon: const Icon(Icons.edit, size: 15),
                        label: const Text('Edit',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context
                            .read<EmployeeBloc>()
                            .add(ToggleEmployeeActive(userId: user.id)),
                        icon: Icon(
                          user.isActive ? Icons.block : Icons.check_circle,
                          size: 15,
                          color: user.isActive ? Colors.orange : Colors.green,
                        ),
                        label: Text(
                          user.isActive ? 'Deactivate' : 'Activate',
                          style: TextStyle(
                            fontSize: 13,
                            color: user.isActive ? Colors.orange : Colors.green,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: user.isActive
                                  ? Colors.orange
                                  : Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _confirmDelete(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Icon(Icons.delete, size: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Table layout for wide screens / tablets ─────────────────────────────────
  Widget _buildTableLayout(EmployeeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text('No.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
              SizedBox(width: 160, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
              SizedBox(width: 90, child: Text('PIN', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
              SizedBox(width: 80, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
              SizedBox(width: 80, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
              Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
            ],
          ),
        ),
        // Data rows
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: state.employees.length,
            itemBuilder: (context, index) {
              final user = state.employees[index];
              final pinVisible = _visiblePins.contains(user.id);
              final isAdmin = user.role == UserRole.admin;
              final roleColor = isAdmin ? const Color(0xFF6C63FF) : Colors.teal;

              return Container(
                key: ValueKey(user.id),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[100]!),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('${index + 1}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      width: 90,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pinVisible ? _displayPin(user.pin) : '••••',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              letterSpacing: 1.5,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (pinVisible) {
                                  _visiblePins.remove(user.id);
                                } else {
                                  _visiblePins.add(user.id);
                                }
                              });
                            },
                            child: Icon(
                              pinVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAdmin ? 'Admin' : 'Cashier',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: user.isActive
                                  ? Colors.green
                                  : Colors.red[300],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: user.isActive
                                  ? Colors.green[700]
                                  : Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showEditDialog(user),
                            color: Colors.grey[600],
                            tooltip: 'Edit',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              user.isActive ? Icons.block : Icons.check_circle,
                              size: 18,
                              color: user.isActive
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            onPressed: () => context
                                .read<EmployeeBloc>()
                                .add(ToggleEmployeeActive(userId: user.id)),
                            tooltip: user.isActive ? 'Deactivate' : 'Activate',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => _confirmDelete(user),
                            color: Colors.red[300],
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
