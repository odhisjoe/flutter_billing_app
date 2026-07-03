enum SyncStatus { disconnected, connecting, connected, syncing, error }

extension SyncStatusX on SyncStatus {
  bool get isActive => this == SyncStatus.connected || this == SyncStatus.syncing;
  bool get isSyncing => this == SyncStatus.syncing;
}
