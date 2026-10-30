import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../pricing.dart';
import '../theme.dart';
import '../tr_text.dart';
import 'work_detail.dart' show PayButton;

/// A request saved but not paid: it hasn't reached our master yet. Kept in
/// this browser for the same 48 hours the Worker keeps it, so a guest who
/// left PayPal (cancel, the back arrow, a closed tab) finds it again.
class Unsent {
  Unsent._();

  static const _key = 'unsentRequest';
  static const keeps = Duration(hours: 48);

  static Future<void> save(String id, String name) async =>
      (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode({
            'id': id,
            'name': name,
            'at': DateTime.now().millisecondsSinceEpoch,
          }));

  /// The waiting request, or null (none, or older than 48 hours).
  static Future<({String id, String name})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
      if (DateTime.now().difference(at) < keeps) {
        return (id: j['id'] as String, name: j['name'] as String? ?? '');
      }
    } catch (_) {
      // A broken save is simply forgotten.
    }
    await prefs.remove(_key);
    return null;
  }

  static Future<void> forget() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

/// "⚠ Not sent yet": the waiting request with its deposit button.
/// Shows nothing when no request is waiting.
class UnsentCard extends StatefulWidget {
  const UnsentCard({super.key});

  @override
  State<UnsentCard> createState() => _UnsentCardState();
}

class _UnsentCardState extends State<UnsentCard> {
  ({String id, String name})? _request;

  @override
  void initState() {
    super.initState();
    Unsent.load().then((r) {
      if (mounted) setState(() => _request = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    if (r == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SP.asphaltCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SP.gold.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('⚠ Not sent to our master yet',
              textAlign: TextAlign.center,
              style: SP.title(18, color: SP.goldLight)),
          const SizedBox(height: 6),
          // The id and the guest's own name for it stay as they are.
          m.Text(r.name.isEmpty ? r.id : '${r.id} · ${r.name}',
              textAlign: TextAlign.center,
              style: SP.body(13.5, color: SP.text)),
          const SizedBox(height: 8),
          Text(
            'Step 2 of 2: pay the 15 zł deposit, and your request goes to '
            'our master.',
            textAlign: TextAlign.center,
            style: SP.body(13, color: SP.text),
          ),
          const SizedBox(height: 12),
          PayButton(
            label: 'Pay the deposit with PayPal · ${zl(15)}',
            item: {'deposit': r.id},
          ),
          const SizedBox(height: 8),
          Text('Not paid within 48 hours, the request is deleted.',
              textAlign: TextAlign.center, style: SP.body(11.5)),
        ],
      ),
    );
  }
}
