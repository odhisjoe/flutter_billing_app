import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';

import '../../../../core/bloc/sync_status_cubit.dart';
import '../../../../core/services/api_config_service.dart';
import '../../../../core/services/api_device_linking_service.dart';
import '../../../../core/services/api_sync_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/sync_status.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/backup_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../../core/utils/printer_driver.dart';
import '../../../../core/utils/printer_manager.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../mpesa/presentation/pages/mpesa_config_page.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Re-initialize printer state whenever settings page opens
    context.read<PrinterBloc>().add(InitPrinterEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final isAdmin = authState.user?.role == UserRole.admin;
          return Center(
            child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
          children: [
            // Profile Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  String shopName = 'Elite Groceries';
                  String initials = 'EG';
                  if (state is ShopLoaded && state.shop.name.isNotEmpty) {
                    shopName = state.shop.name;
                    final parts = shopName.split(' ');
                    initials = parts
                        .take(2)
                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                        .join('');
                    if (initials.isEmpty) initials = 'S';
                  }

                  return Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                blurRadius: 15,
                                spreadRadius: 5,
                              )
                            ]),
                        alignment: Alignment.center,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1)),
                      ),
                      const SizedBox(height: 16),
                      Text(shopName.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),

            if (isAdmin) ...[
              const SizedBox(height: 24),

              // Management Section
              _buildSectionHeader('Management'),
              _buildListGroup(
                children: [
                  _buildListItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Products',
                    subtitle: 'Manage stock and barcodes',
                    onTap: () => context.push('/products'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.people,
                    title: 'Customers',
                    subtitle: 'Manage customers & loyalty points',
                    onTap: () => context.push('/customers'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.business,
                    title: 'Suppliers',
                    subtitle: 'Manage supplier contacts & info',
                    onTap: () => context.push('/suppliers'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.badge,
                    title: 'Employees',
                    subtitle: 'Manage cashiers & admins',
                    onTap: () => context.push('/users'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.assessment,
                    title: 'Reports',
                    subtitle: 'Sales, inventory & profit analytics',
                    onTap: () => context.push('/reports'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.storefront,
                    title: 'Shop Details',
                    subtitle: 'Edit business info & address',
                    onTap: () => context.push('/shop'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Inventory Section
              _buildSectionHeader('Inventory'),
              _buildListGroup(
                children: [
                  _buildListItem(
                    icon: Icons.warning_amber_rounded,
                    title: 'Reorder Alerts',
                    subtitle: 'Products below minimum stock level',
                    onTap: () => context.push('/reorder-alerts'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.add_box,
                    title: 'Receive Stock',
                    subtitle: 'Purchase receiving & stock-in',
                    onTap: () => context.push('/purchase-receiving'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.swap_vert,
                    title: 'Inventory Movement',
                    subtitle: 'View all stock transactions (sales, adjustments, damages)',
                    onTap: () => context.push('/inventory-movement'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Cloud Sync Section (admin only)
              _buildSectionHeader('Cloud Sync'),
              _CloudSyncSection(),
            ],

            const SizedBox(height: 24),

            // Payments Section
            _buildSectionHeader('Payments'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.phone_android,
                  title: 'M-Pesa',
                  subtitle: 'Configure STK Push & Daraja API',
                  onTap: () => showMpesaConfigModal(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Hardware Section
            _buildSectionHeader('Hardware'),
            BlocConsumer<PrinterBloc, PrinterState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: Colors.red));
                } else if (state.status == PrinterStatus.connected) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connected to printer'),
                      backgroundColor: Colors.green));
                }
              },
              builder: (context, state) {
                return _buildListGroup(
                  children: [
                    _buildListItem(
                      icon: Icons.print,
                      title: 'Print Device',
                      subtitleWidget: Row(
                        children: [
                          Flexible(
                            child: Text(
                              state.connectedDevice != null
                                  ? '${state.connectedDevice!.name} (${state.connectedDevice!.displayType})'
                                  : (state.connectedMac != null
                                      ? (state.connectedName ?? 'Printer connected')
                                      : 'No printer connected'),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (state.connectedMac != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.teal[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.teal[200]!)),
                              child: Text(
                                'CONNECTED',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[700]),
                              ),
                            ),
                          ]
                        ],
                      ),
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.status == PrinterStatus.scanning ||
                              state.status == PrinterStatus.connecting)
                            const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                context.read<PrinterBloc>().add(RefreshPrinterEvent());
                                context.read<PrinterBloc>().add(ScanAllDevicesEvent());
                              },
                              color: AppTheme.primaryColor,
                            ),
                          if (state.connectedMac != null)
                            IconButton(
                              icon: const Icon(Icons.power_settings_new, color: Colors.red),
                              onPressed: () => context.read<PrinterBloc>().add(DisconnectPrinterEvent()),
                              color: Colors.red,
                            ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              if (kIsWeb) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Bluetooth settings require a physical Android/iOS device.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                AppSettings.openAppSettings(
                                    type: AppSettingsType.bluetooth);
                              }
                            },
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                    if (state.allDevices.isNotEmpty) ...[
                      _buildDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('AVAILABLE DEVICES',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                                letterSpacing: 1)),
                      ),
                      ...state.allDevices.map((device) => InkWell(
                            onTap: () => context
                                .read<PrinterBloc>()
                                .add(ConnectToDeviceEvent(device)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    device.driverType == PrinterDriverType.bluetooth || device.driverType == PrinterDriverType.windowsBluetooth
                                        ? Icons.bluetooth
                                        : device.driverType == PrinterDriverType.usb
                                            ? Icons.usb
                                            : device.driverType == PrinterDriverType.windowsUsb
                                                ? Icons.print
                                                : Icons.wifi,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(device.name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500)),
                                        Text(device.displayType,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: state.connectedDevice?.address ==
                                              device.address
                                          ? Colors.teal[100]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      state.connectedDevice?.address ==
                                              device.address
                                          ? 'CONNECTED'
                                          : 'TAP TO CONNECT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: state.connectedDevice?.address ==
                                                device.address
                                            ? Colors.teal[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                    _buildDivider(),
                    InkWell(
                      onTap: () => _showAddNetworkPrinterDialog(context),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 18, color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text('Add Network Printer',
                                style: TextStyle(
                                    fontSize: 13, color: AppTheme.primaryColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                kIsWeb
                    ? "Browser receipts use your system print dialog."
                    : "Supports Bluetooth, USB (COM), Network printers & Windows USB (Print Spooler). Tap Add Network Printer to connect via TCP/IP.",
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 24),

            // Data Section
            _buildSectionHeader('Data'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.file_download,
                  title: 'Export Backup',
                  subtitle: 'Download all data as .posbak file',
                  onTap: _exportBackup,
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.file_upload,
                  title: 'Import Backup',
                  subtitle: 'Restore data from a .posbak file',
                  onTap: _importBackup,
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.window,
                  title: 'Download Windows App',
                  subtitle: 'Get the POS for Windows desktop',
                  onTap: () => context.push('/download-windows'),
                ),
              ],
            ),

            const SizedBox(height: 48),
          ],
        ),
        ),
      ),
      );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[50], indent: 64);
  }

  Future<void> _exportBackup() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final json = BackupService.exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final filename =
          'pos_backup_${DateTime.now().toIso8601String().split('T').first}.posbak';

      if (kIsWeb) {
        await downloadBytes(filename, bytes);
      } else {
        final dir = await FilePicker.getDirectoryPath();
        if (dir == null) return;
        final file = File('$dir/$filename');
        await file.writeAsBytes(bytes);
      }

      if (mounted) {
        scaffold.showSnackBar(const SnackBar(
          content: Text('Backup exported successfully'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _importBackup() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['posbak'],
      );
      if (result == null || result.files.isEmpty) return;

      String json;
      if (kIsWeb) {
        json = utf8.decode(result.files.single.bytes!);
      } else {
        json = await File(result.files.single.path!).readAsString();
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await BackupService.importFromJson(json);

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        scaffold.showSnackBar(const SnackBar(
          content: Text('Backup restored successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        scaffold.showSnackBar(SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showAddNetworkPrinterDialog(BuildContext context) {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '9100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Network Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                labelText: 'IP Address or Hostname',
                hintText: 'e.g. 192.168.1.100',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9100',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final host = hostCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
              if (host.isEmpty) return;
              Navigator.pop(ctx);
              context.read<PrinterBloc>().add(ConnectToDeviceEvent(
                    PrinterDevice(
                      name: 'Network ($host:$port)',
                      address: '$host:$port',
                      driverType: PrinterDriverType.network,
                    ),
                  ));
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailingWidget,
    IconData? trailingIcon = Icons.chevron_right,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ]
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

class _CloudSyncSection extends StatefulWidget {
  @override
  State<_CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends State<_CloudSyncSection> {
  final _service = ApiDeviceLinkingService();
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final config = di.sl<ApiConfigService>();
    final url = await config.getServerUrl();
    if (mounted) setState(() => _serverUrl = url);
  }

  Future<void> _showConnectDialog() async {
    final urlCtrl = TextEditingController(text: _serverUrl ?? '');
    final shopNameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isNewShop = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Server Connection'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://your-app.onrender.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter server URL';
                    if (!v.startsWith('http')) return 'Must start with http:// or https://';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('First-time setup?'),
                    const SizedBox(width: 8),
                    Switch(
                      value: isNewShop,
                      onChanged: (v) => setDialogState(() => isNewShop = v),
                    ),
                  ],
                ),
                if (isNewShop) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: shopNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop Name',
                      hintText: 'e.g. Elite Groceries',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (isNewShop && (v == null || v.isEmpty)) return 'Enter a shop name';
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'url': urlCtrl.text.trim(),
                    'shopName': isNewShop ? shopNameCtrl.text.trim() : '',
                    'isNew': isNewShop.toString(),
                  });
                }
              },
              child: Text(isNewShop ? 'Create Shop' : 'Connect'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final url = result['url']!;
      final isNew = result['isNew'] == 'true';
      setState(() => _serverUrl = url);
      final config = di.sl<ApiConfigService>();
      await config.saveServerUrl(url);

      if (isNew) {
        final shopName = result['shopName']!;
        await _bootstrapShop(url, shopName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Shop created and connected!' : 'Server URL saved'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _bootstrapShop(String serverUrl, String shopName) async {
    try {
      final result = await _service.bootstrap(shopName, 'Owner Device');

      if (result == null || result.containsKey('error')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result?['error'] as String? ?? 'Bootstrap failed'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      final jwt = result['token'] as String;
      final tenantId = result['tenantId'] as String;
      final deviceId = result['deviceId'] as String;
      final recoveryPin = result['recoveryPin'] as String?;

      final config = di.sl<ApiConfigService>();
      await config.saveJwtToken(jwt);
      await config.saveTenantId(tenantId);
      await config.saveDeviceId(deviceId);

      if (!mounted) return;
      final syncService = context.read<SyncService>();
      if (syncService is ApiSyncService) {
        await syncService.signInWithJwt(jwt, tenantId);
      }

      if (mounted) {
        if (recoveryPin != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Recovery PIN'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save this recovery PIN — you will need it if you lose all devices.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: SelectableText(
                      recoveryPin,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Format: XXXX-XXXX-XXXX',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('I Saved It'),
                ),
              ],
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shop created and syncing!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _backupNow() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to server'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await syncService.pushAll();
      await _service.createBackup();

      if (mounted) {
        setState(() {}); // trigger rebuild for timeAgo
        scaffold.showSnackBar(
          const SnackBar(content: Text('Backup completed'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _restoreData() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to server'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text('This will replace all local data with the data from the server. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffold = ScaffoldMessenger.of(context);
      try {
        await syncService.pullAll();
        if (mounted) {
          scaffold.showSnackBar(
            const SnackBar(content: Text('Data restored from server'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffold.showSnackBar(
            SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.read<SyncService>();
    final isLinked = syncService.isSignedIn;
    final lastBackup = syncService.lastBackupTime;
    final timeAgo = lastBackup != null
        ? _formatTimeAgo(DateTime.now().difference(lastBackup))
        : null;

    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, syncStatus) {
        return _buildListGroup(
          children: [
            _buildListItem(
              icon: isLinked ? Icons.cloud_done : Icons.cloud_off,
              title: 'Server Connection',
              subtitle: _serverUrl ?? 'Not configured',
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLinked ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isLinked ? 'CONNECTED' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isLinked ? Colors.green[800] : Colors.grey[600],
                  ),
                ),
              ),
              onTap: _showConnectDialog,
            ),
            _buildDivider(),
            _buildListItem(
              icon: Icons.link,
              title: 'Link Devices',
              subtitle: isLinked
                  ? 'Generate QR code to link new devices'
                  : 'Connect to server first',
              trailingWidget: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              onTap: () {
                if (isLinked) {
                  context.push('/admin/link-device');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connect to server first'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
            ),
              if (isLinked) ...[
              _buildDivider(),
              _buildListItem(
                icon: Icons.backup,
                title: 'Backup Now',
                subtitle: timeAgo != null ? 'Last backup: $timeAgo' : 'No backup yet',
                onTap: _backupNow,
              ),
              _buildDivider(),
              _buildListItem(
                icon: Icons.restore,
                title: 'Restore My Data',
                subtitle: 'Pull latest data from server',
                onTap: _restoreData,
              ),
              _buildDivider(),
              _buildListItem(
                icon: Icons.security,
                title: 'Recovery PIN',
                subtitle: 'Use to restore if you lose all devices',
                onTap: _showRecoveryPinDialog,
              ),
            ],
            if (syncStatus == SyncStatus.syncing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Syncing...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[50], indent: 64);
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
          ],
        ),
      ),
    );
  }

  Future<void> _showRecoveryPinDialog() async {
    final config = di.sl<ApiConfigService>();
    final serverUrl = await config.getServerUrl();
    final token = await config.getJwtToken();
    if (serverUrl.isEmpty || token == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('Recovery PIN'),
          ],
        ),
        content: const Text(
          'Generate a new recovery PIN? The previous one will stop working.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Generate New PIN'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _service.setRecoveryPin();

      if (result == null || result.containsKey('error')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result?['error'] as String? ?? 'Failed'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      final newPin = result['recoveryPin'] as String?;
      if (newPin != null && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.security, color: Colors.orange),
                SizedBox(width: 8),
                Text('New Recovery PIN'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save this PIN somewhere safe. You will need it if you lose all devices.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: SelectableText(
                    newPin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Format: XXXX-XXXX-XXXX',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('I Saved It'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate recovery PIN: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
