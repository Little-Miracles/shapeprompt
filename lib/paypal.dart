import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'web_nav.dart';

/// PayPal checkout through our Worker (worker/src/index.js): the PayPal
/// secret stays on the server. Sandbox — no real money.
class PayPal {
  PayPal._();

  static const _worker =
      'https://shapeprompt-paypal.axis-mobile-studio.workers.dev';
  static const _pendingKey = 'paypalPending';

  /// Creates the order and leaves for PayPal. What was ordered is kept
  /// locally, to show on the "Paid" screen when the customer comes back.
  static Future<void> checkout({
    required String title,
    required double amount,
  }) async {
    final here = '${Uri.base.origin}${Uri.base.path}';
    final res = await http
        .post(Uri.parse('$_worker/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'amount': amount.toStringAsFixed(2),
              'returnUrl': '$here?paypal=return',
              'cancelUrl': '$here?paypal=cancel',
            }))
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final approve = data['approveUrl'] as String?;
    if (res.statusCode != 200 || approve == null) {
      throw Exception(data['error'] ?? 'PayPal error ${res.statusCode}');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey,
        jsonEncode({'id': data['id'], 'title': title, 'amount': amount}));
    goTo(approve);
  }

  /// What the customer was paying for (null if nothing is pending).
  static Future<Map<String, dynamic>?> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> forget() async =>
      (await SharedPreferences.getInstance()).remove(_pendingKey);

  /// Takes the money after the customer approved it on PayPal.
  static Future<Map<String, dynamic>> capture(String orderId) async {
    final res = await http.post(Uri.parse('$_worker/orders/$orderId/capture'),
        headers: {
          'Content-Type': 'application/json'
        }).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'PayPal error ${res.statusCode}');
    }
    return data;
  }
}
