import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, PhoneAuthCredential;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/auth_session.dart';
import '../../../platform/auth/firebase_phone_auth.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../di/push_providers.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  /// Echoed back by the backend on dev/staging builds so the field can be
  /// prefilled. Null in production.
  final String? devOtp;

  final String? name;
  final String? fromPath;

  /// Set when the code comes from Firebase Phone Authentication (6 digits):
  /// Firebase checks the code and the app signs in with the Firebase ID
  /// token. Null for our own SMS OTP (4 digits).
  final FirebasePhoneVerification? firebase;

  /// Android verified the number by itself before the screen opened.
  final PhoneAuthCredential? autoCredential;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.devOtp,
    this.name,
    this.fromPath,
    this.firebase,
    this.autoCredential,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  /// Firebase codes are 6 digits; our SMS OTP is 4.
  int get _otpLength =>
      widget.firebase != null ? FirebasePhoneVerification.codeLength : 4;

  late final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );

  late final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  Timer? _timer;

  int _resendCountdown = 30;

  bool _isVerifying = false;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      debugPrint('[AUTH] OTP screen opened for +91 ${widget.phoneNumber}');
    }

    _startResendTimer();

    // -------------------------------------------------------------------------
    // DEV OTP AUTO FILL (only when backend sends it — never hardcode in prod)
    // -------------------------------------------------------------------------

    final code = widget.firebase == null ? widget.devOtp : null;

    if (code != null && code.length == _otpLength) {
      for (int i = 0; i < _otpLength; i++) {
        _controllers[i].text = code[i];
      }
    }

    // -------------------------------------------------------------------------
    // FIREBASE: auto-retrieved code (Android) and late failures
    // -------------------------------------------------------------------------

    final firebase = widget.firebase;
    if (firebase != null) {
      firebase.onAutoVerified = (credential) {
        if (mounted) _signInWithFirebase(credential);
      };
      firebase.onFailed = (message) {
        if (mounted && !_isVerifying) {
          _showSnackBar(AppSnackbarType.error, message);
        }
      };
      final auto = widget.autoCredential;
      if (auto != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _signInWithFirebase(auto);
        });
      }
    }

    // -------------------------------------------------------------------------
    // AUTO FOCUS
    // -------------------------------------------------------------------------

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _focusNodes[0].requestFocus();
    });
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _timer?.cancel();

    widget.firebase?.onAutoVerified = null;
    widget.firebase?.onFailed = null;

    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  // ===========================================================================
  // RESEND TIMER
  // ===========================================================================

  void _startResendTimer() {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _resendCountdown = 30;
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  // ===========================================================================
  // ENTERED OTP
  // ===========================================================================

  String get _enteredOtp {
    return _controllers.map((controller) => controller.text).join();
  }

  // ===========================================================================
  // OTP DIGIT CHANGE
  // ===========================================================================

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      Haptics.light();

      // Move to next box
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last box
        _focusNodes[index].unfocus();

        if (_enteredOtp.length == _otpLength && !_isVerifying) {
          _verifyOtp();
        }
      }
    } else {
      // Backspace on empty box -> previous box
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // VERIFY OTP
  // ===========================================================================

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final enteredOtp = _enteredOtp;

    if (enteredOtp.length < _otpLength) {
      _showSnackBar(
        AppSnackbarType.warning,
        'Please enter the $_otpLength-digit code',
      );

      return;
    }

    final firebase = widget.firebase;
    if (firebase != null) {
      final PhoneAuthCredential credential;
      try {
        credential = firebase.credentialFor(enteredOtp);
      } on FirebaseAuthException catch (e) {
        _showSnackBar(AppSnackbarType.error, describeFirebaseAuthError(e));
        return;
      }
      await _signInWithFirebase(credential);
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    Haptics.medium();

    if (kDebugMode) {
      debugPrint('[AUTH] OTP entered');
    }

    final notifier = ref.read(authViewModelProvider.notifier);
    final fcmToken = ref.read(pushServiceProvider).token;

    final session = await notifier.verifyOtp(
      phone: widget.phoneNumber,
      otp: enteredOtp,
      name: widget.name,
      fcmToken: fcmToken,
    );

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    // -------------------------------------------------------------------------
    // OTP FAILURE
    // -------------------------------------------------------------------------

    if (session == null) {
      _onVerifyFailed(notifier.lastError ?? 'Invalid OTP. Please try again.');
      return;
    }

    _completeLogin(session);
  }

  // ===========================================================================
  // FIREBASE SIGN-IN
  // ===========================================================================

  /// Firebase checked the code (or Android verified the number by itself);
  /// the Firebase ID token is exchanged for our session at
  /// `/food/auth/user/firebase-login`, and the Firebase session is signed out
  /// straight away — the app runs on our JWT.
  Future<void> _signInWithFirebase(PhoneAuthCredential credential) async {
    if (_isVerifying) return;

    final smsCode = credential.smsCode;
    if (smsCode != null && smsCode.length == _otpLength) {
      for (int i = 0; i < _otpLength; i++) {
        _controllers[i].text = smsCode[i];
      }
    }

    setState(() {
      _isVerifying = true;
    });

    Haptics.medium();

    final String idToken;
    try {
      idToken = await FirebasePhoneVerification.idTokenFor(credential);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      _onVerifyFailed(describeFirebaseAuthError(e));
      return;
    }

    if (!mounted) return;

    final notifier = ref.read(authViewModelProvider.notifier);
    final fcmToken = ref.read(pushServiceProvider).token;

    final session = await notifier.firebaseLogin(
      idToken: idToken,
      name: widget.name,
      fcmToken: fcmToken,
    );

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (session == null) {
      _onVerifyFailed(
        notifier.lastError ?? 'Could not sign in. Please try again.',
      );
      return;
    }

    _completeLogin(session);
  }

  void _onVerifyFailed(String message) {
    _showSnackBar(AppSnackbarType.error, message);

    Haptics.error();

    for (final controller in _controllers) {
      controller.clear();
    }

    setState(() {});

    _focusNodes[0].requestFocus();
  }

  void _completeLogin(AuthSession session) {
    // -------------------------------------------------------------------------
    // OTP SUCCESS
    // -------------------------------------------------------------------------

    Haptics.success();

    if (kDebugMode) {
      debugPrint('[AUTH] Login completed · redirecting');
    }

    final target = widget.fromPath ?? RouteNames.home;

    // -------------------------------------------------------------------------
    // NEW USER -> PROFILE SETUP
    // -------------------------------------------------------------------------

    if (session.needsProfileSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(redirectTo: target),
        ),
      );

      return;
    }

    // -------------------------------------------------------------------------
    // EXISTING USER
    // -------------------------------------------------------------------------

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    context.go(target);
  }

  // ===========================================================================
  // RESEND OTP
  // ===========================================================================

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

    Haptics.light();

    final firebase = widget.firebase;
    if (firebase != null) {
      final sent = await firebase.send(resend: true);
      if (!mounted) return;
      switch (sent.status) {
        case FirebaseCodeStatus.failed:
          _showSnackBar(
            AppSnackbarType.error,
            sent.message ?? 'Could not resend OTP.',
          );
        case FirebaseCodeStatus.autoVerified:
          await _signInWithFirebase(sent.credential!);
        case FirebaseCodeStatus.sent:
          _startResendTimer();
          _showSnackBar(
            AppSnackbarType.success,
            'New OTP code sent to +91 ${widget.phoneNumber}',
          );
      }
      return;
    }

    final result = await ref
        .read(authViewModelProvider.notifier)
        .requestOtp(widget.phoneNumber);

    if (!mounted) return;

    if (!result.ok) {
      _showSnackBar(
        AppSnackbarType.error,
        ref.read(authViewModelProvider.notifier).lastError ??
            'Could not resend OTP.',
      );

      return;
    }

    _startResendTimer();

    _showSnackBar(
      AppSnackbarType.success,
      'New OTP code sent to +91 ${widget.phoneNumber}',
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(AppSnackbarType type, String message) {
    if (!mounted) return;

    AppSnackbar.show(
      context,
      message,
      type: type,
      duration: const Duration(seconds: 2),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final isKeyboardOpen = keyboardHeight > 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // -------------------------------------------------------------------------
    // COLORS
    // -------------------------------------------------------------------------

    final textColor = isDark ? Colors.white : const Color(0xFF171717);

    final secondaryColor = isDark ? Colors.white70 : const Color(0xFF777777);

    final cardColor = isDark
        ? const Color(0xFF1C1C1C).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.96);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,

      // Important:
      // Keyboard open hone par Scaffold resize nahi hoga.
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [
          // ===================================================================
          // BACKGROUND IMAGE
          // ===================================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/otp_screen.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // ===================================================================
          // BACK BUTTON
          // ===================================================================
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,

            child: Material(
              color: Colors.black.withValues(alpha: 0.30),

              shape: const CircleBorder(),

              child: InkWell(
                onTap: () {
                  Haptics.light();
                  context.pop();
                },

                customBorder: const CircleBorder(),

                child: const Padding(
                  padding: EdgeInsets.all(8),

                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // ===================================================================
          // OTP CARD
          // ===================================================================
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),

            curve: Curves.easeOut,

            left: 24,
            right: 24,

            // =================================================================
            // CARD POSITION
            //
            // 0.22 = card upar shifted
            //
            // Agar aur upar karna ho:
            // 0.24 / 0.25
            // =================================================================
            bottom: isKeyboardOpen
                ? keyboardHeight + 10
                : screenSize.height * 0.24,

            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isKeyboardOpen
                    ? screenSize.height - keyboardHeight - 20
                    : screenSize.height * 0.50,
              ),

              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,

                  borderRadius: BorderRadius.circular(26),

                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.white,
                    width: 1,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.07,
                      ),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      // =======================================================
                      // LOCK ICON
                      // =======================================================

                      Container(
                        width: 42,
                        height: 42,

                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEEF0),
                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // =======================================================
                      // TITLE
                      // =======================================================
                      Text(
                        'Verify OTP 🔒',
                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 3),

                      // =======================================================
                      // SUBTITLE
                      // =======================================================
                      Text(
                        'Enter the $_otpLength-digit code sent to',
                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 1),

                      // =======================================================
                      // PHONE NUMBER
                      // =======================================================
                      Text(
                        '+91 ${widget.phoneNumber}',
                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // =======================================================
                      // OTP BOXES
                      // =======================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                        children: List.generate(_otpLength, (index) {
                          return _buildOtpBox(index, isDark);
                        }),
                      ),

                      const SizedBox(height: 11),

                      // =======================================================
                      // VERIFY BUTTON
                      // =======================================================
                      SizedBox(
                        width: double.infinity,
                        height: 44,

                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDeep,
                              ],
                            ),

                            borderRadius: BorderRadius.circular(23),

                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryAlpha(0.23),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),

                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyOtp,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,

                              disabledBackgroundColor: Colors.transparent,

                              shadowColor: Colors.transparent,

                              elevation: 0,

                              padding: EdgeInsets.zero,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),

                            child: _isVerifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,

                                    children: [
                                      const Text(
                                        'Verify & Continue',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(width: 6),

                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // =======================================================
                      // RESEND OTP
                      // =======================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Text(
                            'Didn\'t receive OTP?',

                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryColor,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(width: 3),

                          if (_resendCountdown > 0)
                            Text(
                              'Resend in '
                              '${_resendCountdown}s',

                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                height: 1.1,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _handleResendOtp,

                              child: Text(
                                'Resend OTP',

                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  height: 1.1,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // =======================================================
                      // SECURITY
                      // =======================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),

                          const SizedBox(width: 4),

                          Flexible(
                            child: Text(
                              'Your login is secure and protected',

                              textAlign: TextAlign.center,

                              style: TextStyle(
                                fontSize: 9.5,
                                color: secondaryColor,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OTP BOX
  // ===========================================================================

  Widget _buildOtpBox(int index, bool isDark) {
    final isFocused = _focusNodes[index].hasFocus;

    final hasValue = _controllers[index].text.isNotEmpty;

    // =========================================================================
    // IMPORTANT DARK MODE COLORS
    //
    // Dark mode:
    //   Box  = dark
    //   Text = WHITE
    //
    // Light mode:
    //   Box  = white
    //   Text = BLACK
    // =========================================================================

    final Color otpBoxColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    final Color otpTextColor = isDark ? Colors.white : const Color(0xFF171717);

    final Color normalBorderColor = isDark
        ? const Color(0xFF555555)
        : const Color(0xFFDCDCDC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),

      // Six boxes have to fit the same card as four.
      width: _otpLength > 4 ? 40 : 52,
      height: _otpLength > 4 ? 46 : 52,

      decoration: BoxDecoration(
        // ---------------------------------------------------------------------
        // DARK MODE BOX
        // ---------------------------------------------------------------------

        color: otpBoxColor,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: isFocused || hasValue ? AppColors.primary : normalBorderColor,

          width: isFocused || hasValue ? 1.7 : 1.0,
        ),

        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primaryAlpha(0.11),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),

      child: Center(
        child: TextField(
          controller: _controllers[index],

          focusNode: _focusNodes[index],

          keyboardType: TextInputType.number,

          textInputAction: index == _otpLength - 1
              ? TextInputAction.done
              : TextInputAction.next,

          textAlign: TextAlign.center,

          maxLength: 1,

          cursorColor: AppColors.primary,

          // ===================================================================
          // OTP TEXT
          // ===================================================================
          //
          // Dark mode -> WHITE
          // Light mode -> BLACK
          //
          // ===================================================================
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: otpTextColor,
          ),

          inputFormatters: [FilteringTextInputFormatter.digitsOnly],

          decoration: const InputDecoration(
            counterText: '',

            border: InputBorder.none,

            enabledBorder: InputBorder.none,

            focusedBorder: InputBorder.none,

            disabledBorder: InputBorder.none,

            errorBorder: InputBorder.none,

            focusedErrorBorder: InputBorder.none,

            filled: false,

            isDense: true,

            contentPadding: EdgeInsets.zero,
          ),

          // ===================================================================
          // DIGIT CHANGE
          // ===================================================================
          onChanged: (value) {
            _onOtpDigitChanged(index, value);
          },

          // ===================================================================
          // SUBMIT
          // ===================================================================
          onSubmitted: (_) {
            if (index == _otpLength - 1 &&
                _enteredOtp.length == _otpLength &&
                !_isVerifying) {
              _verifyOtp();
            }
          },
        ),
      ),
    );
  }
}
