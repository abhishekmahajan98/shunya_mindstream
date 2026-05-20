import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/auth_api.dart';
import '../core/models/profile.dart';
import '../core/services/session_service.dart';

class AuthState {
  final String? userId;
  final String? email;
  final Profile? profile;
  final bool loading;

  const AuthState({
    this.userId,
    this.email,
    this.profile,
    this.loading = true,
  });

  AuthState copyWith({
    String? userId,
    String? email,
    Profile? profile,
    bool? loading,
    bool clearUser = false,
  }) {
    return AuthState(
      userId: clearUser ? null : (userId ?? this.userId),
      email: clearUser ? null : (email ?? this.email),
      profile: clearUser ? null : (profile ?? this.profile),
      loading: loading ?? this.loading,
    );
  }

  bool get isAuthenticated => userId != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _rehydrate();
    SessionService.onSessionExpired = () {
      logout();
    };
  }

  /// Load session from secure storage on app start.
  Future<void> _rehydrate() async {
    final session = await SessionService.loadSession();
    final token = session['accessToken'];
    final uid = session['userId'];
    if (token != null && uid != null) {
      state = AuthState(
        userId: uid,
        email: session['email'],
        profile: Profile(
          id: uid,
          fullName: session['fullName'] ?? '',
          role: session['role'] ?? 'analyst',
        ),
        loading: false,
      );
    } else {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true);
    final data = await AuthApi.login(email: email, password: password);
    await _applySession(data);
  }

  Future<void> signup(String email, String password, String fullName, String role) async {
    state = state.copyWith(loading: true);
    final data = await AuthApi.signup(
        email: email, password: password, fullName: fullName, role: role);
    await _applySession(data);
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final profile = Profile.fromJson(data['profile'] as Map<String, dynamic>);
    await SessionService.saveSession(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      userId: data['user_id'] as String,
      email: data['email'] as String,
      fullName: profile.fullName,
      role: profile.role,
    );
    state = AuthState(
      userId: data['user_id'] as String,
      email: data['email'] as String,
      profile: profile,
      loading: false,
    );
  }

  Future<void> logout() async {
    await SessionService.clearSession();
    state = const AuthState(loading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
