import 'package:flutter/material.dart' hide Text;

import '../theme.dart';
import '../tr_text.dart';

/// The order terms: what every payment on the site agrees to.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static void open(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const TermsScreen()));

  static const _parts = <(String, String)>[
    (
      'Who we are',
      'ShapePrompt is a small creative 3D printing workshop. Write to us: '
          'hello@craftaxi.com. This site is a hackathon demo: payments run in '
          'PayPal Sandbox and no real money is charged. The seller\'s full '
          'details will be listed here before real sales begin.'
    ),
    ('Age', 'You must be 18 or older to pay on this site.'),
    (
      'Prices',
      'All prices are in zł and include VAT 23%. Delivery, if any, is shown '
          'before you pay.'
    ),
    (
      'Ready works',
      'Every ready work is printed only after you order it, with your own '
          'words on it — on the front of the base or hidden underneath. That '
          'is our workshop\'s rule. Because it is made to your specification, '
          'the 14-day right of withdrawal does not apply (Art. 38 point 3 of '
          'the Polish Consumer Rights Act).'
    ),
    (
      'Figurines made to your request',
      'They are made to your own specification, so the 14-day right of '
          'withdrawal does not apply (Art. 38 point 3 of the Polish Consumer '
          'Rights Act). Before printing, our master sends you 2–3 pictures of '
          'the 3D model. Your approval of these pictures is our agreement: the '
          'figurine is printed as approved. We print with plastic filament, '
          'not resin: small details come out simpler, thin parts may be glued '
          'on, and for now a figurine has one color.'
    ),
    (
      'The 15 zł deposit',
      'A request reaches our master only with the deposit. It pays for '
          'looking at your request and making the 3D model, and it counts '
          'toward the price. It is returned only if our master declines your '
          'request before starting work. If the picture can\'t be used, our '
          'master asks for another one; the deposit waits for this request '
          'for 30 days, then the request is closed and the deposit is not '
          'returned. A request that breaks the rules below is closed without '
          'returning the deposit.'
    ),
    (
      '3D files',
      'The download starts right after the payment, so you lose the 14-day '
          'right of withdrawal (Art. 38 point 13 of the Polish Consumer Rights '
          'Act) — you agree to this before paying. Personal use only: '
          'reselling or sharing the file, and selling prints of it, is not '
          'allowed.'
    ),
    (
      'What we never make',
      'Weapons and weapon parts, replicas and ammunition; drones of any kind '
          'used in war and their parts; bombs, grenades, missiles and '
          'explosives; nude or sexual images; blood and cruelty; hate '
          'symbols; film, cartoon and game heroes and logos that belong to '
          'companies; anything against the law. Our master may decline any '
          'request.'
    ),
    (
      'Your picture',
      'You confirm that the picture is yours or that you may use it. Photos '
          'of the finished figurine, with the ShapePrompt watermark, may '
          'appear in the portfolio of our master. You choose whether our master '
          'may sell copies of the figurine (10% off your next figurine) or it '
          'stays only yours (exclusive, +25–50% to the price).'
    ),
    (
      'Complaints',
      'If what you receive doesn\'t match the approved model, or arrives '
          'damaged, write to hello@craftaxi.com with photos. We answer within '
          '14 days. Your legal rights for goods that don\'t match the '
          'agreement stay in force.'
    ),
    (
      'Privacy',
      'Your email and picture are kept for 90 days, only to answer your '
          'request, and are not given to anyone. Payments are handled by '
          'PayPal; we never see your card. To protect the workshop, an '
          'address that tried to order forbidden things is kept for 24 '
          'hours, and the email and PayPal account of a customer our master '
          'blocked are kept for one year (our legitimate interest, GDPR '
          'Art. 6(1)(f)). A blocked customer can write to us to explain.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
        children: [
          const BackRow(),
          Text('Order terms', textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 18),
          for (final (head, text) in _parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(head, style: SP.title(15, color: SP.gold)),
                  const SizedBox(height: 4),
                  Text(text, style: SP.body(13, color: SP.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Before any payment: the payer is an adult and accepts the terms.
/// Asked once per visit.
class PayConsent {
  PayConsent._();
  static bool _given = false;

  static Future<bool> ask(BuildContext context) async {
    if (_given) return true;
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _ConsentDialog());
    _given = ok == true;
    return _given;
  }
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _adult = false;
  bool _terms = false;

  @override
  Widget build(BuildContext context) {
    final ready = _adult && _terms;
    return AlertDialog(
      backgroundColor: SP.asphaltCard,
      title: Text('Before you pay', style: SP.title(20, color: SP.goldLight)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _check(_adult, (v) => setState(() => _adult = v),
              'I am 18 years old or older.'),
          _check(_terms, (v) => setState(() => _terms = v),
              'I have read and accept the order terms.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => TermsScreen.open(context),
              child: Text('Read the order terms',
                  style: SP.body(13, color: SP.gold, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: SP.body(13)),
        ),
        TextButton(
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text('Continue to PayPal',
              style: SP.body(13,
                  color: ready ? SP.goldLight : SP.text.withOpacity(0.4),
                  weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _check(bool value, ValueChanged<bool> onChanged, String text) =>
      InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              activeColor: SP.gold,
              checkColor: SP.asphaltDeep,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(text, style: SP.body(13, color: SP.text)),
              ),
            ),
          ],
        ),
      );
}
