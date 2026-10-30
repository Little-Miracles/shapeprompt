import 'package:flutter/material.dart' hide Text;

import '../paypal.dart';
import '../pricing.dart';
import '../theme.dart';
import '../web_nav.dart';
import '../tr_text.dart';
import 'start.dart';
import 'unsent.dart';

/// Where PayPal sends the customer back: takes the payment and says thank
/// you — or, if they cancelled, says the order is still waiting.
class PaidScreen extends StatefulWidget {
  const PaidScreen({super.key, required this.orderId, this.cancelled = false});
  final String? orderId;
  final bool cancelled;

  @override
  State<PaidScreen> createState() => _PaidScreenState();
}

class _PaidScreenState extends State<PaidScreen> {
  Map<String, dynamic>? _order; // what was ordered, saved before PayPal
  Map<String, dynamic>? _result; // PayPal's answer after capture
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    _order = await PayPal.pending();
    if (widget.cancelled || widget.orderId == null) {
      await PayPal.forget();
      if (mounted) setState(() {});
      return;
    }
    try {
      final r = await PayPal.capture(widget.orderId!);
      await PayPal.forget();
      // The deposit is paid: the request has reached our master.
      if (r['request'] != null) await Unsent.forget();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = !widget.cancelled && _result == null && _error == null;
    final paid = _result?['status'] == 'COMPLETED';
    final download = _result?['download'] as String?;
    final request = _result?['request'] as String?;
    return SPScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
        children: [
          Image.asset('assets/anim/hello/01.webp', height: 200),
          const SizedBox(height: 18),
          if (busy) ...[
            const Center(child: CircularProgressIndicator(color: SP.gold)),
            const SizedBox(height: 14),
            Text('Confirming your payment…',
                textAlign: TextAlign.center, style: SP.title(20)),
          ] else if (paid) ...[
            Text('Thank you! Your order is paid.',
                textAlign: TextAlign.center, style: SP.title(24)),
            const SizedBox(height: 16),
            _line('Your order', _order?['title'] as String? ?? ''),
            _line(
                'Total paid',
                zl(double.parse(
                    (_result!['amount']?['value'] ?? '0').toString()))),
            _line('PayPal order number', _result!['id'] as String? ?? ''),
            const SizedBox(height: 12),
            if (download != null) ...[
              Text(
                'Your file is ready. The link works for 7 days.',
                textAlign: TextAlign.center,
                style: SP.body(13, color: SP.text),
              ),
              const SizedBox(height: 14),
              Center(
                child: GoldButton(
                    label: 'Download the file', onTap: () => goTo(download)),
              ),
            ] else if (request != null)
              Text(
                'Your request $request has reached our master together with '
                'the deposit. Our master writes to you within 24 hours with '
                'the price.',
                textAlign: TextAlign.center,
                style: SP.body(13, color: SP.text),
              )
            else
              Text(
                'Our master will start printing and will write to you '
                'when the parcel is on its way.',
                textAlign: TextAlign.center,
                style: SP.body(13, color: SP.text),
              ),
          ] else if (widget.cancelled) ...[
            Text('The payment was cancelled.',
                textAlign: TextAlign.center, style: SP.title(22)),
            const SizedBox(height: 10),
            Text('Nothing was charged. You can come back to it anytime.',
                textAlign: TextAlign.center, style: SP.body(13)),
          ] else if (_error?.contains('blocked') ?? false) ...[
            Text('We can\'t take orders from you.',
                textAlign: TextAlign.center, style: SP.title(22)),
            const SizedBox(height: 10),
            Text(
                'Nothing was charged. If you think this is a mistake, write '
                'to hello@craftaxi.com.',
                textAlign: TextAlign.center,
                style: SP.body(13)),
          ] else ...[
            Text('The payment did not go through.',
                textAlign: TextAlign.center, style: SP.title(22)),
            const SizedBox(height: 10),
            Text('Nothing was charged. Please try again a little later.',
                textAlign: TextAlign.center, style: SP.body(13)),
          ],
          // Not paid: a waiting request is right here to pay again.
          if (!busy && !paid) ...[
            const SizedBox(height: 18),
            const UnsentCard(),
          ],
          const SizedBox(height: 18),
          Text(
            'Demo mode: PayPal Sandbox. No real money is charged.',
            textAlign: TextAlign.center,
            style: SP
                .body(11, color: SP.purple)
                .copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 26),
          if (!busy)
            Center(
              child: GoldButton(
                label: 'Back to the shop',
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const StartScreen())),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String what, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(what, style: SP.body(13))),
            Expanded(
              child: Text(value, style: SP.body(13, color: SP.goldLight)),
            ),
          ],
        ),
      );
}
