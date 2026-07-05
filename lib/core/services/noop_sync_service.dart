import 'dart:async';
import 'sync_service.dart';
import 'sync_status.dart';

class NoopSyncService implements SyncService {
  @override
  bool get isAvailable => false;

  @override
  SyncStatus get currentStatus => SyncStatus.disconnected;

  @override
  final Stream<SyncStatus> statusStream =
      const Stream.empty();

  @override
  bool get isSignedIn => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signIn(String email, String password) async {
    throw UnsupportedError('Use device pairing instead of email/password sign-in');
  }

  @override
  Future<void> signOut() async {}

  @override
  DateTime? get lastBackupTime => null;

  @override
  bool get autoBackupEnabled => false;

  @override
  Future<void> pushAll() async {}

  @override
  Future<void> pullAll() async {}

  @override
  Future<void> dispose() async {}
}
