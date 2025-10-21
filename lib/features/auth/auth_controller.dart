import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modelo simple de usuario
class UserAccount {
  final String username;
  final String password; // demo: en real, hash
  final bool isAdmin;
  bool isLocked;
  int failedAttempts;

  UserAccount({
    required this.username,
    required this.password,
    required this.isAdmin,
    this.isLocked = false,
    this.failedAttempts = 0,
  });
}

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.errorMessage});

  AuthState copyWith({bool? isLoading, String? errorMessage}) => AuthState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class AuthController extends Notifier<AuthState> {
  // “DB” en memoria para demo
  final Map<String, UserAccount> _users = {
    'admin': UserAccount(username: 'admin', password: 'admin123', isAdmin: true),
    'vanesa': UserAccount(username: 'vanesa', password: 'vane123', isAdmin: false),
  };

  static const int maxFailed = 3;

  @override
  AuthState build() => const AuthState();

  Future<bool> signIn(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 250));

    final user = _users[username.toLowerCase()];
    if (user == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Usuario inexistente.');
      return false;
    }

    if (!user.isAdmin && user.isLocked) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Error nº 5: su contraseña ha sido blanqueada. Contacte a su administrador para programar una nueva.',
      );
      return false;
    }

    if (password == user.password) {
      user.failedAttempts = 0;
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } else {
      if (!user.isAdmin) {
        user.failedAttempts += 1;
        if (user.failedAttempts >= maxFailed) {
          user.isLocked = true;
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Error nº 5: su contraseña ha sido blanqueada. Contacte a su administrador.',
          );
          return false;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Credenciales incorrectas.');
      return false;
    }
  }

  bool isAdmin(String username) => _users[username.toLowerCase()]?.isAdmin ?? false;

  void adminResetUser(String username) {
    final user = _users[username.toLowerCase()];
    if (user != null) {
      user.isLocked = false;
      user.failedAttempts = 0;
    }
  }
}

/// Provider para Riverpod 3+
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
