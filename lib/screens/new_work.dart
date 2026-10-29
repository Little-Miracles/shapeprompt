import 'package:flutter/material.dart';

import 'photo_order.dart';

/// Something we have never made: from the customer's photo or drawing, or
/// from an idea in words. Both open one page — the picture is optional.
enum NewWork { photo, idea }

class NewWorkScreen {
  NewWorkScreen._();

  static void open(BuildContext context, NewWork kind, {String? thing}) =>
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PhotoOrderScreen(thing: thing)));
}
