import 'dart:async';

import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/data/datasources/google_auth_remote_datasource.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final GoogleAuthRemoteDataSource _dataSource;

  @override
  Stream<UserSession?> observeAuthState() => _dataSource.authStateChanges();

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    try {
      final session = await _dataSource.signInWithGoogle();
      return Ok(session);
    } on AuthFailure catch (failure) {
      return Err(failure);
    } on GoogleSignInException catch (error) {
      return Err(_mapGoogleException(error));
    } on FirebaseAuthException catch (error) {
      return Err(_mapFirebaseException(error));
    } catch (error, stack) {
      debugPrint('Auth sign-in failed: ${error.runtimeType}');
      debugPrint('$stack');
      return const Err(AuthFailure.unknown());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Ok<void>(null);
    } catch (error, stack) {
      debugPrint('Auth sign-out failed: ${error.runtimeType}');
      debugPrint('$stack');
      return const Err(AuthFailure.unknown());
    }
  }

  AuthFailure _mapGoogleException(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const AuthFailure.cancelled();
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const AuthFailure.configuration();
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        return const AuthFailure.unknown();
    }
  }

  AuthFailure _mapFirebaseException(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return const AuthFailure.network();
      case 'invalid-credential':
      case 'account-exists-with-different-credential':
        return const AuthFailure.configuration();
      default:
        return const AuthFailure.unknown();
    }
  }
}
