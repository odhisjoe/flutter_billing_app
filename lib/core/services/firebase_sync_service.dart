import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:hive/hive.dart';
import '../data/hive_database.dart';
import '../utils/sync_serializer.dart';
import 'sync_service.dart';
import 'sync_status.dart';

class FirebaseSyncService implements SyncService {
  late final auth.FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.disconnected;
  bool _isPulling = false;
  StreamSubscription? _authSub;
  final List<StreamSubscription> _boxSubs = [];
  Timer? _backupTimer;
  DateTime? _lastBackupTime;
  String? _tenantId;
  bool _disposed = false;

  static const _backupInterval = Duration(hours: 1);

  @override
  bool get isAvailable => true;

  @override
  SyncStatus get currentStatus => _status;

  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  DateTime? get lastBackupTime => _lastBackupTime;

  @override
  bool get autoBackupEnabled => isSignedIn;

  void setTenantId(String? tenantId) {
    _tenantId = tenantId;
  }

  String get _prefix {
    final uid = _auth.currentUser?.uid;
    if (_tenantId != null) return 'tenants/$_tenantId';
    if (uid != null) return 'super-admins/$uid';
    return '';
  }

  CollectionReference _col(String name) =>
      _firestore.collection('$_prefix/$name');

  @override
  Future<void> initialize() async {
    _auth = auth.FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;

    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _setStatus(SyncStatus.connected);
        _startWatching();
        _startAutoBackup();
      } else {
        _setStatus(SyncStatus.disconnected);
        _stopWatching();
        _stopAutoBackup();
      }
    });

    if (_auth.currentUser != null) {
      _setStatus(SyncStatus.connected);
      _startWatching();
      _startAutoBackup();
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    _setStatus(SyncStatus.connecting);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await pullAll();
    } catch (e) {
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _stopWatching();
    _stopAutoBackup();
    _tenantId = null;
    await _auth.signOut();
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

  void _onBoxEvent(String collection, BoxEvent event) {
    if (_isPulling) return;
    if (!isSignedIn) return;

    if (_prefix.isEmpty) return;
    final ref = _col(collection).doc(event.key);
    if (event.deleted) {
      ref.delete();
    } else {
      final data = SyncSerializer.modelToMap(collection, event.value);
      if (data != null) {
        ref.set(data);
      }
    }
  }

  @override
  Future<void> pushAll() async {
    if (!isSignedIn) return;
    if (_prefix.isEmpty) return;
    _setStatus(SyncStatus.syncing);
    try {
      await _pushBox('products', HiveDatabase.productBox);
      await _pushBox('shop', HiveDatabase.shopBox);
      await _pushBox('sales', HiveDatabase.salesBox);
      await _pushBox('inventory', HiveDatabase.inventoryBox);
      await _pushBox('customers', HiveDatabase.customerBox);
      await _pushBox('suppliers', HiveDatabase.supplierBox);
      await _pushBox('users', HiveDatabase.usersBox);
      _lastBackupTime = DateTime.now();
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  Future<String?> tenantLookup(String adminUid) async {
    try {
      final tenants = await _firestore
          .collection('tenants')
          .where('ownerAdminUid', isEqualTo: adminUid)
          .limit(1)
          .get();
      if (tenants.docs.isNotEmpty) {
        _tenantId = tenants.docs.first.id;
        return _tenantId;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pushBox<T>(String collection, Box<T> box) async {
    final batch = _firestore.batch();
    for (final entry in box.toMap().entries) {
      final data = SyncSerializer.modelToMap(collection, entry.value);
      if (data != null) {
        batch.set(_col(collection).doc(entry.key), data);
      }
    }
    await batch.commit();
  }

  @override
  Future<void> pullAll() async {
    if (!isSignedIn) return;
    if (_prefix.isEmpty) return;
    _isPulling = true;
    _setStatus(SyncStatus.syncing);
    try {
      await _pullCollection('products', HiveDatabase.productBox);
      await _pullCollection('shop', HiveDatabase.shopBox);
      await _pullCollection('sales', HiveDatabase.salesBox);
      await _pullCollection('inventory', HiveDatabase.inventoryBox);
      await _pullCollection('customers', HiveDatabase.customerBox);
      await _pullCollection('suppliers', HiveDatabase.supplierBox);
      await _pullCollection('users', HiveDatabase.usersBox);
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _setStatus(SyncStatus.error);
      rethrow;
    } finally {
      _isPulling = false;
    }
  }

  Future<void> _pullCollection<T>(
      String collection, Box<T> box) async {
    final snapshot = await _col(collection).get();
    if (snapshot.docs.isEmpty) return;

    await box.clear();
    for (final doc in snapshot.docs) {
      final model = SyncSerializer.mapToModel(collection, doc.data() as Map<String, dynamic>);
      if (model != null) {
        await box.put(doc.id, model as T);
      }
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopAutoBackup();
    await _authSub?.cancel();
    _stopWatching();
    await _statusController.close();
  }
}
