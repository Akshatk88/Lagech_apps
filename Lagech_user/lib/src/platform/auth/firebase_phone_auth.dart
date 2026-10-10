import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// How a [FirebasePhoneVerification.send] call ended.
enum FirebaseCodeStatus { sent, autoVerified, failed }

class FirebaseCodeResult {
  const FirebaseCodeResult._(this.status, {this.credential, this.message});

  const FirebaseCodeResult.sent() : this._(FirebaseCodeStatus.sent);

  const FirebaseCodeResult.autoVerified(PhoneAuthCredential credential)
      : this._(FirebaseCodeStatus.autoVerified, credential: credential);

  const FirebaseCodeResult.failed(String message)
      : this._(FirebaseCodeStatus.failed, message: message);

  final FirebaseCodeStatus status;
  final PhoneAuthCredential? credential;
  final String? message;
}

/// Firebase Phone Authentication for one phone number (India, +91).
///
/// Firebase sends and checks the 6-digit SMS code; the app then exchanges the
/// Firebase ID token for our own JWT at `POST /food/auth/user/firebase-login`
/// and signs straight back out of Firebase — the app session is ours, not
/// Firebase's.
///
/// [send] completes on the first of: code sent, verified automatically
/// (Android auto-retrieval / instant verification) or failed. Anything Firebase
/// reports after that (auto-retrieval of the SMS while the OTP screen is open,
/// a late failure) goes to [onAutoVerified] / [onFailed].
class FirebasePhoneVerification {
  FirebasePhoneVerification(this.phone);

  /// Firebase codes are always 6 digits.
  static const int codeLength = 6;

  /// The 10-digit number, without the country code.
  final String phone;

  String? _verificationId;
  int? _resendToken;

  void Function(PhoneAuthCredential credential)? onAutoVerified;
  void Function(String message)? onFailed;

  bool get hasCode => _verificationId != null;

  /// Sends the code (or re-sends it, reusing Firebase's resend token).
  Future<FirebaseCodeResult> send({bool resend = false}) async {
    final first = Completer<FirebaseCodeResult>();
    void settle(FirebaseCodeResult result, void Function() later) {
      if (!first.isCompleted) {
        first.complete(result);
      } else {
        later();
      }
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (credential) => settle(
          FirebaseCodeResult.autoVerified(credential),
          () => onAutoVerified?.call(credential),
        ),
        verificationFailed: (error) {
          final message = describeFirebaseAuthError(error);
          settle(FirebaseCodeResult.failed(message), () => onFailed?.call(message));
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken ?? _resendToken;
          settle(const FirebaseCodeResult.sent(), () {});
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
        },
      );
    } catch (error) {
      settle(FirebaseCodeResult.failed(describeFirebaseAuthError(error)), () {});
    }
    return first.future;
  }

  /// The credential for a code the user typed.
  PhoneAuthCredential credentialFor(String smsCode) {
    final id = _verificationId;
    if (id == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Please request a code first.',
      );
    }
    return PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode);
  }

  /// Signs in to Firebase with [credential], returns the Firebase ID token and
  /// signs out of Firebase again. Throws [FirebaseAuthException] (use
  /// [describeFirebaseAuthError] for the message).
  static Future<String> idTokenFor(PhoneAuthCredential credential) async {
    final auth = FirebaseAuth.instance;
    try {
      final result = await auth.signInWithCredential(credential);
      final token = await result.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw FirebaseAuthException(
          code: 'no-id-token',
          message: 'Phone verification did not complete. Please try again.',
        );
      }
      return token;
    } finally {
      await signOut();
    }
  }

  /// The app never keeps a Firebase session.
  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Nothing to sign out of.
    }
  }
}

/// A Firebase phone-auth error in plain words.
String describeFirebaseAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Too many attempts from this device. Please wait a while and try again.';
      case 'invalid-phone-number':
        return 'This mobile number is not valid. Please check it and try again.';
      case 'quota-exceeded':
        return 'We cannot send more codes right now. Please try again later.';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please check it and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'This code has expired. Please request a new one.';
      case 'invalid-verification-id':
      case 'missing-verification-id':
        return 'Please request a new code and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'user-disabled':
        return 'This phone number has been blocked from signing in. Please contact support.';
      case 'app-not-authorized':
      case 'invalid-app-credential':
      case 'missing-app-credential':
      case 'missing-client-identifier':
      case 'captcha-check-failed':
        return 'Phone verification could not be completed on this device. Please try again or contact support.';
      case 'web-context-cancelled':
      case 'web-context-already-presented':
        return 'Verification was cancelled. Please try again.';
    }
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
  }
  return 'Could not verify your phone number. Please try again.';
}
