/// Silent stand-in outside the browser.
class Voice {
  Voice._();
  static final instance = Voice._();

  bool get canListen => false;
  bool get canSpeak => false;

  void speak(String text, String lang) {}
  void stopSpeaking() {}

  void listen(String lang,
      {required void Function(String text) onResult,
      required void Function() onEnd}) {
    onEnd();
  }

  void stopListening() {}
}
