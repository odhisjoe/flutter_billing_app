import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/utils/pin_encryption_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../../core/usecase/usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final AuthRepository authRepository;
  final PinEncryptionService _encryptionService;

  AuthBloc({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.authRepository,
    PinEncryptionService? encryptionService,
  })  : _encryptionService = encryptionService ?? PinEncryptionService(),
        super(const AuthState()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
    on<PinChangedEvent>(_onPinChanged);
  }

  Future<void> _onCheckAuth(
      CheckAuthEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await getCurrentUserUseCase(NoParams());
    if (result.isRight()) {
      final user = result.getRight().toNullable();
      if (user != null) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } else {
      final failure = result.getLeft().toNullable()!;
      emit(state.copyWith(
          status: AuthStatus.unauthenticated, message: failure.message));
    }
  }

  Future<void> _onLogin(
      LoginEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await loginUseCase(
        LoginParams(pin: event.pin, role: event.role));
    if (result.isRight()) {
      final user = result.getRight().toNullable()!;
      final isDefault = _encryptionService.verify('1234', user.pin);
      final needsPinChange = user.isPinReset ||
          (isDefault && user.role != UserRole.cashier);
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          needsPinChange: needsPinChange));
    } else {
      final failure = result.getLeft().toNullable()!;
      emit(state.copyWith(
          status: AuthStatus.unauthenticated, message: failure.message));
    }
  }

  Future<void> _onLogout(
      LogoutEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
    await logoutUseCase(NoParams());
  }

  Future<void> _onPinChanged(
      PinChangedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(needsPinChange: false));
  }
}
