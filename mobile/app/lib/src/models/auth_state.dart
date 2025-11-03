import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_state.freezed.dart';

/// Authentication state
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthStateInitial;
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.authenticated(User user) = AuthStateAuthenticated;
  const factory AuthState.unauthenticated() = AuthStateUnauthenticated;
  const factory AuthState.error(String message) = AuthStateError;
}
