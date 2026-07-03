import 'sync_status.dart';

abstract class SyncService {
  bool get isAvailable;
  SyncStatus get currentStatus;
  Stream<SyncStatus> get statusStream;

  Future<void> initialize();

  Future<void> signIn(String email, String password);
  Future<void> signOut();
  bool get isSignedIn;

  Future<void> pushAll();
  Future<void> pullAll();

  DateTime? get lastBackupTime;
  bool get autoBackupEnabled;

  Future<void> dispose();
}
