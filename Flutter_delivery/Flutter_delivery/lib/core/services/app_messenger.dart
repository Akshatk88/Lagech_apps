import 'package:flutter/material.dart';

/// App-wide handle on the root ScaffoldMessenger, so code that has no
/// BuildContext (controllers, the overlay hand-off) can still tell the rider
/// something. Passed to `MaterialApp.router(scaffoldMessengerKey: ...)`.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows [message] as a floating snackbar from anywhere in the app.
///
/// Long enough to read: this is used for refusals the rider has to act on (such
/// as "deposit your cash to take cash orders"), which used to fail silently.
void showAppMessage(String message, {Duration duration = const Duration(seconds: 7)}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null || message.trim().isEmpty) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
}
