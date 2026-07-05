import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../data/hive_database.dart';
import '../utils/sync_serializer.dart';
import 'api_config_service.dart';
import 'sync_service.dart';
import 'sync_status.dart';

class ApiSyncService implements SyncService {
  final ApiConfigService _config;
  final Dio _dio;
  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.disconnected;
  bool _isPulling = false;
  final List<StreamSubscription> _boxSubs = [];
  Timer? _backupTimer;
  DateTime? _lastBackupTime;
  bool _disposed = false;

  static const _backupInterval = Duration(hours: 1);

  @override
  bool get isAvailable => true;

  @override
  SyncStatus get currentStatus => _status;

  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  @override
  bool get isSignedIn => _token != null;

  @override
  DateTime? get lastBackupTime => _lastBackupTime;

  @override
  bool get autoBackupEnabled => isSignedIn;

  String? _token;
  String? _tenantId;

  ApiSyncService({
    required ApiConfigService config,
    Dio? dio,
  })  : _config = config,
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  @override
  Future<void> initialize() async {
    if (await _config.isConfigured()) {
      _token = await _config.getJwtToken();
      _tenantId = await _config.getTenantId();
      if (_token != null && _tenantId != null) {
        _setStatus(SyncStatus.connected);
        _startWatching();
        _startAutoBackup();
      }
    } else {
      _setStatus(SyncStatus.disconnected);
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    throw UnsupportedError(
      'Use device pairing instead of email/password sign-in',
    );
  }

  Future<void> signInWithJwt(String token, String tenantId) async {
    _token = token;
    _tenantId = tenantId;
    await _config.saveJwtToken(token);
    await _config.saveTenantId(tenantId);
    _setStatus(SyncStatus.connected);
    _startWatching();
    _startAutoBackup();
    await pushAll();
  }

  @override
  Future<void> signOut() async {
    _stopWatching();
    _stopAutoBackup();
    _token = null;
    _tenantId = null;
    await _config.clear();
    _setStatus(SyncStatus.disconnected);
  }

  void _startAutoBackup() {
    _stopAutoBackup();
    _backupTimer = Timer.periodic(_backupInterval, (_) {
      if (isSignedIn) {
        pushAll().then((_) {
          _lastBackupTime = DateTime.now();
        }).catchError((_) {});
      }
    });
  }

  void _stopAutoBackup() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    if (!_disposed) {
      _statusController.add(status);
    }
  }

  void _startWatching() {
    if (_boxSubs.isNotEmpty) return;
    _boxSubs.add(HiveDatabase.productBox.watch().listen((e) => _onBoxEvent('products', e)));
    _boxSubs.add(HiveDatabase.shopBox.watch().listen((e) => _onBoxEvent('shop', e)));
    _boxSubs.add(HiveDatabase.salesBox.watch().listen((e) => _onBoxEvent('sales', e)));
    _boxSubs.add(HiveDatabase.inventoryBox.watch().listen((e) => _onBoxEvent('inventory', e)));
    _boxSubs.add(HiveDatabase.customerBox.watch().listen((e) => _onBoxEvent('customers', e)));
    _boxSubs.add(HiveDatabase.supplierBox.watch().listen((e) => _onBoxEvent('suppliers', e)));
    _boxSubs.add(HiveDatabase.usersBox.watch().listen((e) => _onBoxEvent('users', e)));
  }

  void _stopWatching() {
    for (final sub in _boxSubs) {
      sub.cancel();
    }
    _boxSubs.clear();
  }

  void _onBoxEvent(String entityType, BoxEvent event) {
    if (_isPulling) return;
    if (!isSignedIn) return;

    final data = SyncSerializer.modelToMap(entityType, event.value);
    if (data != null) {
      _pushEntries([
        {
          'entityType': entityType,
          'entityId': event.key,
          'payload': data,
          'version': 1,
        },
      ]).catchError((_) {});
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  Future<void> _pushEntries(List<Map<String, dynamic>> entries) async {
    try {
      await _dio.post(
        '${await _config.getServerUrl()}/api/sync/push',
        data: {'entries': entries},
        options: Options(headers: _headers),
      );
    } catch (_) {}
  }

  @override
  Future<void> pushAll() async {
    if (!isSignedIn) return;
    _setStatus(SyncStatus.syncing);
    try {
      final serverUrl = await _config.getServerUrl();
      if (serverUrl.isEmpty) return;

      final entries = <Map<String, dynamic>>[];

      void addEntries(String type, Box box) {
        for (final entry in box.toMap().entries) {
          final data = SyncSerializer.modelToMap(type, entry.value);
          if (data != null) {
            entries.add({
              'entityType': type,
              'entityId': entry.key,
              'payload': data,
              'version': 1,
            });
          }
        }
      }

      addEntries('products', HiveDatabase.productBox);
      addEntries('shop', HiveDatabase.shopBox);
      addEntries('sales', HiveDatabase.salesBox);
      addEntries('inventory', HiveDatabase.inventoryBox);
      addEntries('customers', HiveDatabase.customerBox);
      addEntries('suppliers', HiveDatabase.supplierBox);
      addEntries('users', HiveDatabase.usersBox);

      if (entries.isNotEmpty) {
        await _dio.post(
          '$serverUrl/api/sync/push',
          data: {'entries': entries},
          options: Options(headers: _headers),
        );
      }

      _lastBackupTime = DateTime.now();
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }

  @override
  Future<void> pullAll() async {
    if (!isSignedIn) return;
    _isPulling = true;
    _setStatus(SyncStatus.syncing);
    try {
      final serverUrl = await _config.getServerUrl();
      if (serverUrl.isEmpty) return;

      final response = await _dio.get(
        '$serverUrl/api/sync/pull/full',
        options: Options(headers: _headers),
      );

      final records = response.data as List<dynamic>;
      if (records.isEmpty) return;

      await _applyRecords(records);
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _setStatus(SyncStatus.error);
    } finally {
      _isPulling = false;
    }
  }

  Future<void> _applyRecords(List<dynamic> records) async {
    final byType = <String, List<Map<String, dynamic>>>{};

    for (final r in records) {
      final type = r['entityType'] as String;
      byType.putIfAbsent(type, () => []);
      byType[type]!.add({
        'id': r['entityId'] as String,
        'payload': r['payload'] as Map<String, dynamic>,
      });
    }

    for (final entry in byType.entries) {
      final box = _boxForType(entry.key);
      if (box == null) continue;
      for (final item in entry.value) {
        final model = SyncSerializer.mapToModel(entry.key, item['payload']);
        if (model != null) {
          await box.put(item['id'], model);
        }
      }
    }
  }

  Box? _boxForType(String type) {
    switch (type) {
      case 'products': return HiveDatabase.productBox;
      case 'shop': return HiveDatabase.shopBox;
      case 'sales': return HiveDatabase.salesBox;
      case 'inventory': return HiveDatabase.inventoryBox;
      case 'customers': return HiveDatabase.customerBox;
      case 'suppliers': return HiveDatabase.supplierBox;
      case 'users': return HiveDatabase.usersBox;
      default: return null;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopAutoBackup();
    _stopWatching();
    await _statusController.close();
  }
}
