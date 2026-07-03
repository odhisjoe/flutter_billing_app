part of 'mpesa_bloc.dart';

abstract class MpesaEvent extends Equatable {
  const MpesaEvent();
  @override
  List<Object?> get props => [];
}

class LoadMpesaConfig extends MpesaEvent {}

class SaveMpesaConfig extends MpesaEvent {
  final MpesaConfig config;
  const SaveMpesaConfig(this.config);
  @override
  List<Object?> get props => [config];
}

class TestMpesaConnection extends MpesaEvent {}

class InitiateStkPush extends MpesaEvent {
  final String phone;
  final double amount;
  final String reference;
  const InitiateStkPush({
    required this.phone,
    required this.amount,
    required this.reference,
  });
  @override
  List<Object?> get props => [phone, amount, reference];
}

class CheckPaymentStatus extends MpesaEvent {
  final String checkoutRequestId;
  const CheckPaymentStatus(this.checkoutRequestId);
  @override
  List<Object?> get props => [checkoutRequestId];
}

class ResetMpesaStatus extends MpesaEvent {}
