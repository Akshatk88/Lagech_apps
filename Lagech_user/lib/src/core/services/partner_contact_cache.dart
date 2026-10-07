import 'package:shared_preferences/shared_preferences.dart';

/// Remembers a rider's phone per order.
///
/// The order read only carries the rider's number while the order is live; once
/// it is delivered the server returns just an id. Saving it while the order is
/// being tracked keeps "Contact Delivery Partner" working on the delivered page.
class PartnerContactCache {
  PartnerContactCache._();

  static String _key(String orderId) => 'partner_phone_$orderId';

  static Future<void> remember(String orderId, String phone) async {
    final number = phone.trim();
    if (orderId.isEmpty || number.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key(orderId)) != number) {
        await prefs.setString(_key(orderId), number);
      }
    } catch (_) {}
  }

  static Future<String> phoneFor(String orderId) async {
    if (orderId.isEmpty) return '';
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(orderId)) ?? '';
    } catch (_) {
      return '';
    }
  }
}
