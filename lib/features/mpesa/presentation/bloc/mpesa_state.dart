part of 'mpesa_bloc.dart';

class MpesaState extends Equatable {
  final MpesaConfig config;
  final bool loading;
  final bool testing;
  final String? error;
  final String? success;
  final String? paymentStatus; // idle | sending | sent | checking | paid | failed
  final String? checkoutRequestId;
  final String? mpesaRef;

  const MpesaState({
    this.config = const MpesaConfig(),
    this.loading = false,
    this.testing = false,
    this.error,
    this.success,
    this.paymentStatus = 'idle',
    this.checkoutRequestId,
    this.mpesaRef,
  });

  MpesaState copyWith({
    MpesaConfig? config,
    bool? loading,
    bool? testing,
    String? error,
    String? success,
    String? paymentStatus,
    String? checkoutRequestId,
    String? mpesaRef,
  }) {
    return MpesaState(
      config: config ?? this.config,
      loading: loading ?? this.loading,
      testing: testing ?? this.testing,
      error: error,
      success: success,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      checkoutRequestId: checkoutRequestId ?? this.checkoutRequestId,
      mpesaRef: mpesaRef ?? this.mpesaRef,
    );
  }

  @override
  List<Object?> get props => [
    config,
    loading,
    testing,
    error,
    success,
    paymentStatus,
    checkoutRequestId,
    mpesaRef,
  ];
}
