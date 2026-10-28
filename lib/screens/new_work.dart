import 'package:flutter/material.dart' hide Text;

import '../theme.dart';
import '../tr_text.dart';
import 'photo_order.dart';

/// Something we have never made: from the customer's photo or drawing, or
/// from an idea in words. The pages are being built; for now each one
/// says what it will do.
enum NewWork { photo, idea }

class NewWorkScreen extends StatelessWidget {
  const NewWorkScreen({super.key, required this.kind, this.thing});
  final NewWork kind;

  /// What the guest asked the dragon for, if they came from the chat.
  final String? thing;

  static void open(BuildContext context, NewWork kind, {String? thing}) =>
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => kind == NewWork.photo
                  ? PhotoOrderScreen(thing: thing)
                  : NewWorkScreen(kind: kind, thing: thing)));

  @override
  Widget build(BuildContext context) {
    final photo = kind == NewWork.photo;
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text(photo ? 'I have a photo or drawing' : 'I have an idea',
              textAlign: TextAlign.center, style: SP.title(24)),
          if (thing != null) ...[
            const SizedBox(height: 8),
            Text(thing!,
                textAlign: TextAlign.center,
                style: SP.title(19, color: SP.goldLight)),
          ],
          const SizedBox(height: 28),
          Icon(photo ? Icons.photo_camera_outlined : Icons.lightbulb_outline,
              size: 72, color: SP.gold),
          const SizedBox(height: 20),
          Text(
            photo
                ? 'Here you will upload your photo or drawing and tell me '
                    'your wishes. Our master will look at it and write to you.'
                : 'Here you will describe your idea in words and get two or three '
                    'sketches to start from. Our master will then write to '
                    'you.',
            textAlign: TextAlign.center,
            style: SP.body(14, color: SP.text),
          ),
          const SizedBox(height: 14),
          Text('This page is being built.',
              textAlign: TextAlign.center,
              style: SP
                  .body(12, color: SP.purple)
                  .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
