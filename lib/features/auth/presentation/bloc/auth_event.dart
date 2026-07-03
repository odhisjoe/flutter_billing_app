part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthEvent extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String pin;
  final UserRole role;
  const LoginEvent({required this.pin, required this.role});

  @override
  List<Object?> get props => [pin, role];
}

class LogoutEvent extends AuthEvent {}

class PinChangedEvent extends AuthEvent {}
