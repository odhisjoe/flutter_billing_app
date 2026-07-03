part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? message;
  final bool? needsPinChange;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.message,
    this.needsPinChange = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? message,
    bool? needsPinChange,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      message: message,
      needsPinChange: needsPinChange ?? this.needsPinChange ?? false,
    );
  }

  @override
  List<Object?> get props => [status, user, message, needsPinChange];
}
