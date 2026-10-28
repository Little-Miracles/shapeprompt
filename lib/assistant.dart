import 'dart:convert';

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'human.dart';
import 'paypal.dart';

/// Turnstile site key (public). The secret half lives only in the Worker.
const turnstileSiteKey = '0x4AAAAAAFpdLMYKA0XvZmWK';

/// What the dragon chose, priced by the Worker from the shop's catalog.
class Pick {
  Pick(this.json);
  final Map<String, dynamic> json;

  String get work => json['work'] as String;
  String get title => json['title'] as String;
  double get piece => (json['piece'] as num).toDouble();
  double get delivery => (json['delivery'] as num).toDouble();
  double get total => (json['total'] as num).toDouble();

  /// What the Worker needs to price the order again, at checkout.
  Map<String, String> get item => {
        for (final k in ['work', 'material', 'color', 'size', 'box'])
          k: json[k] as String,
      };
}

/// A custom request the dragon prepared: one of our works in another
/// size, material or color. The price is approximate; the maker confirms it.
class Custom {
  Custom(this.json);
  final Map<String, dynamic> json;

  String get title => json['title'] as String;
  double get piece => (json['piece'] as num).toDouble();
  double get delivery => (json['delivery'] as num).toDouble();
  double get total => (json['total'] as num).toDouble();
  double? get budget => (json['budget'] as num?)?.toDouble();
}

class Reply {
  Reply(this.text, this.picks, this.custom, this.route, this.newThing);
  final String text; // in English; the app translates it
  final List<Pick> picks;
  final Custom? custom;

  /// Something we have never made: 'photo', 'idea' or 'both' pages to offer.
  final String? route;

  /// Its name, as the guest called it ("Puss in Boots").
  final String? newThing;
}

/// The dragon's brain: our Worker, which asks Gemini. The key never comes
/// to the website.
class Assistant {
  Assistant._();
  static final instance = Assistant._();

  String? _session;

  /// [history] is the whole conversation, oldest first, with the guest's
  /// newest message last.
  Future<Reply> ask(List<({String text, bool mine})> history) async {
    final body = <String, dynamic>{
      'messages': [
        for (final m in history) {'text': m.text, 'mine': m.mine}
      ],
    };
    if (_session != null) {
      body['session'] = _session;
    } else {
      body['human'] = await humanToken(turnstileSiteKey);
    }
    var res = await _post(body);
    // The session ran out: one new check and try again.
    if (res.statusCode == 403 && _session != null) {
      _session = null;
      body
        ..remove('session')
        ..['human'] = await humanToken(turnstileSiteKey);
      res = await _post(body);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw AssistantError(res.statusCode);
    }
    _session = data['session'] as String?;
    final custom = data['custom'];
    return Reply(
      data['reply'] as String? ?? '',
      [
        for (final p in data['picks'] as List? ?? const [])
          Pick(p as Map<String, dynamic>)
      ],
      custom is Map<String, dynamic> ? Custom(custom) : null,
      data['route'] as String?,
      data['newThing'] as String?,
    );
  }

  /// The dragon looks at the guest's picture and fills in a card.
  Future<({Map<String, dynamic> card, String reply})> readPhoto(
      Uint8List jpeg, String note, String lang) async {
    // Written by the dragon straight in the guest's language.
    final data = await _call('/photo/read',
        {'image': base64Encode(jpeg), 'note': note, 'lang': lang});
    return (
      card: data['card'] as Map<String, dynamic>,
      reply: data['reply'] as String? ?? ''
    );
  }

  /// Sends the picture order to the maker; returns its number.
  Future<String> sendPhotoRequest(
      Uint8List jpeg, Map<String, dynamic> card, String email) async {
    final data = await _call('/photo/requests', {
      'image': base64Encode(jpeg),
      'card': card,
      'email': email,
      'consent': true,
      'rights': true,
    });
    return data['id'] as String;
  }

  /// A call that needs a person: the session, or a new Turnstile check.
  Future<Map<String, dynamic>> _call(
      String path, Map<String, dynamic> body) async {
    if (_session != null) {
      body['session'] = _session;
    } else {
      body['human'] = await humanToken(turnstileSiteKey);
    }
    var res = await _post(body, path);
    if (res.statusCode == 403 && _session != null) {
      _session = null;
      body
        ..remove('session')
        ..['human'] = await humanToken(turnstileSiteKey);
      res = await _post(body, path);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) throw AssistantError(res.statusCode);
    _session = data['session'] as String? ?? _session;
    return data;
  }

  /// Sends a custom request to the maker; returns its number.
  Future<String> sendRequest(Custom custom, String email) async {
    final body = <String, dynamic>{
      'custom': custom.json,
      'email': email,
      'consent': true,
    };
    if (_session != null) {
      body['session'] = _session;
    } else {
      body['human'] = await humanToken(turnstileSiteKey);
    }
    var res = await _post(body, '/requests');
    if (res.statusCode == 403 && _session != null) {
      _session = null;
      body
        ..remove('session')
        ..['human'] = await humanToken(turnstileSiteKey);
      res = await _post(body, '/requests');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) throw AssistantError(res.statusCode);
    return data['id'] as String;
  }

  Future<http.Response> _post(Map<String, dynamic> body,
          [String path = '/chat']) =>
      http
          .post(Uri.parse('${PayPal.worker}$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
}

class AssistantError implements Exception {
  AssistantError(this.status);
  final int status;

  /// Too many questions from here, or the free Gemini quota is used up
  /// for now: either way, "a little later".
  bool get tooMany => status == 429 || status == 503;
}
