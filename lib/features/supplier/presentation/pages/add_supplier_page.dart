import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/supplier/domain/entities/supplier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';

class AddSupplierPage extends StatefulWidget {
  final Supplier? supplier;
  const AddSupplierPage({super.key, this.supplier});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.supplier!;
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phoneNumber;
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final supplier = Supplier(
      id: _isEditing ? widget.supplier!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      createdAt: _isEditing ? widget.supplier!.createdAt : DateTime.now(),
    );

    if (_isEditing) {
      context.read<SupplierBloc>().add(UpdateSupplier(supplier));
    } else {
      context.read<SupplierBloc>().add(AddSupplier(supplier));
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Supplier Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address (optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_isEditing ? 'Update Supplier' : 'Add Supplier',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }
}
