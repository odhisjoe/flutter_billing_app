import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SecondaryDb {
  static Database? _db;

  static bool get isAvailable => !kIsWeb;

  static Future<Database?> get database async {
    if (kIsWeb) return null;
    _db ??= await _init();
    return _db;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'secondary.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_sync_queue_status ON sync_queue(status)
        ''');
        await db.execute('''
          CREATE TABLE mpesa_requests (
            checkout_request_id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            amount REAL NOT NULL,
            phone TEXT NOT NULL,
            paid INTEGER NOT NULL DEFAULT 0,
            mpesa_ref TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE mpesa_config (
            id TEXT PRIMARY KEY DEFAULT 'default',
            consumer_key TEXT NOT NULL DEFAULT '',
            consumer_secret TEXT NOT NULL DEFAULT '',
            passkey TEXT NOT NULL DEFAULT '',
            shortcode TEXT NOT NULL DEFAULT '',
            server_url TEXT NOT NULL DEFAULT '',
            is_sandbox INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      },
    );
  }

  static Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }

  // ── SyncQueue ───────────────────────────────────────────────────────────
  static Future<int> enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async {
    final db = await database;
    if (db == null) return -1;
    return db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'status': 'pending',
      'retry_count': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSync({int limit = 50}) async {
    final db = await database;
    if (db == null) return [];
    return db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  static Future<void> updateSyncStatus(int id, String status) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'sync_queue',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> incrementSyncRetry(int id) async {
    final db = await database;
    if (db == null) return;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  static Future<int> pendingSyncCount() async {
    final db = await database;
    if (db == null) return 0;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM sync_queue WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── M-Pesa Requests ─────────────────────────────────────────────────────
  static Future<void> insertMpesaRequest({
    required String checkoutRequestId,
    required String saleId,
    required double amount,
    required String phone,
  }) async {
    final db = await database;
    if (db == null) return;
    await db.insert('mpesa_requests', {
      'checkout_request_id': checkoutRequestId,
      'sale_id': saleId,
      'amount': amount,
      'phone': phone,
      'paid': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> confirmMpesaPayment({
    required String checkoutRequestId,
    required String mpesaRef,
  }) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'mpesa_requests',
      {'paid': 1, 'mpesa_ref': mpesaRef, 'updated_at': DateTime.now().toIso8601String()},
      where: 'checkout_request_id = ?',
      whereArgs: [checkoutRequestId],
    );
  }

  static Future<Map<String, dynamic>?> getMpesaRequest(String checkoutRequestId) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query(
      'mpesa_requests',
      where: 'checkout_request_id = ?',
      whereArgs: [checkoutRequestId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<Map<String, dynamic>>> searchMpesaPayments(String query) async {
    final db = await database;
    if (db == null) return [];
    return db.query(
      'mpesa_requests',
      where: 'checkout_request_id LIKE ? OR mpesa_ref LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
      limit: 20,
    );
  }

  static Future<bool> isSalePaid(String saleId) async {
    final db = await database;
    if (db == null) return false;
    final results = await db.query(
      'mpesa_requests',
      where: 'sale_id = ? AND paid = 1',
      whereArgs: [saleId],
    );
    return results.isNotEmpty;
  }

  // ── M-Pesa Config ───────────────────────────────────────────────────────
  static Future<void> saveMpesaConfig({
    required String consumerKey,
    required String consumerSecret,
    required String passkey,
    required String shortcode,
    required String serverUrl,
    required bool isSandbox,
  }) async {
    final db = await database;
    if (db == null) return;
    await db.insert('mpesa_config', {
      'id': 'default',
      'consumer_key': consumerKey,
      'consumer_secret': consumerSecret,
      'passkey': passkey,
      'shortcode': shortcode,
      'server_url': serverUrl,
      'is_sandbox': isSandbox ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getMpesaConfig() async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query('mpesa_config', where: 'id = ?', whereArgs: ['default']);
    return results.isNotEmpty ? results.first : null;
  }
}
