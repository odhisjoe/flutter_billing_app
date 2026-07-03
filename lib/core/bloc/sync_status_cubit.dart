import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/sync_service.dart';
import '../services/sync_status.dart';

class SyncStatusCubit extends Cubit<SyncStatus> {
  final SyncService _syncService;
  StreamSubscription? _sub;

  SyncStatusCubit(this._syncService) : super(_syncService.currentStatus) {
    _sub = _syncService.statusStream.listen(emit);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
