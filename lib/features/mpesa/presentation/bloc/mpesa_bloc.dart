import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/mpesa_repository_impl.dart';

part 'mpesa_event.dart';
part 'mpesa_state.dart';

class MpesaBloc extends Bloc<MpesaEvent, MpesaState> {
  final MpesaRepositoryImpl repository;

  MpesaBloc({required this.repository}) : super(const MpesaState()) {
    on<LoadMpesaConfig>(_onLoadConfig);
    on<SaveMpesaConfig>(_onSaveConfig);
    on<TestMpesaConnection>(_onTestConnection);
    on<InitiateStkPush>(_onInitiateStkPush);
    on<CheckPaymentStatus>(_onCheckPaymentStatus);
    on<ResetMpesaStatus>(_onReset);
  }

  Future<void> _onLoadConfig(LoadMpesaConfig event, Emitter<MpesaState> emit) async {
    emit(state.copyWith(loading: true));
    try {
      final config = await repository.loadConfig();
      emit(state.copyWith(config: config, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _onSaveConfig(SaveMpesaConfig event, Emitter<MpesaState> emit) async {
    emit(state.copyWith(loading: true));
    try {
      await repository.saveConfig(event.config);
      emit(state.copyWith(
        config: event.config,
        loading: false,
        success: 'Configuration saved',
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _onTestConnection(TestMpesaConnection event, Emitter<MpesaState> emit) async {
    emit(state.copyWith(testing: true));
    try {
      final result = await repository.testConnection();
      emit(state.copyWith(
        testing: false,
        success: result.message,
        error: result.success ? null : result.message,
      ));
    } catch (e) {
      emit(state.copyWith(testing: false, error: e.toString()));
    }
  }

  Future<void> _onInitiateStkPush(InitiateStkPush event, Emitter<MpesaState> emit) async {
    emit(state.copyWith(paymentStatus: 'sending'));
    try {
      final result = await repository.stkPush(
        phone: event.phone,
        amount: event.amount,
        reference: event.reference,
      );
      if (result.success) {
        emit(state.copyWith(
          paymentStatus: 'sent',
          checkoutRequestId: result.checkoutRequestId,
          success: result.message,
        ));
      } else {
        emit(state.copyWith(paymentStatus: 'failed', error: result.message));
      }
    } catch (e) {
      emit(state.copyWith(paymentStatus: 'failed', error: e.toString()));
    }
  }

  Future<void> _onCheckPaymentStatus(CheckPaymentStatus event, Emitter<MpesaState> emit) async {
    emit(state.copyWith(paymentStatus: 'checking'));
    try {
      final status = await repository.checkStatus(event.checkoutRequestId);
      if (status.paid) {
        emit(state.copyWith(
          paymentStatus: 'paid',
          mpesaRef: status.mpesaRef,
          success: 'Payment received',
        ));
      } else {
        emit(state.copyWith(paymentStatus: 'sent'));
      }
    } catch (e) {
      emit(state.copyWith(paymentStatus: 'sent', error: e.toString()));
    }
  }

  void _onReset(ResetMpesaStatus event, Emitter<MpesaState> emit) {
    emit(const MpesaState());
  }
}
