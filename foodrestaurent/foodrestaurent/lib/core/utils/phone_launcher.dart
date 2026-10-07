import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer for [phone]; tells the user when it can't.
Future<void> callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final number = phone.trim();
  if (number.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Phone number is not available.')),
    );
    return;
  }
  var ok = false;
  try {
    ok = await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the phone dialer.')),
    );
  }
}
