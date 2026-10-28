import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Longest side of the picture we send: enough for the maker to see the
/// details, small enough to send quickly.
const _maxSide = 1600;

/// Opens the file chooser and returns the picture as a JPEG no bigger than
/// [_maxSide] on its longest side (or null if nothing was chosen).
Future<Uint8List?> pickPhoto() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  final chosen = Completer<html.File?>();
  input.onChange.listen((_) => chosen.complete(input.files?.first));
  input.click();
  final file = await chosen.future;
  if (file == null) return null;

  final url = html.Url.createObjectUrlFromBlob(file);
  try {
    final img = html.ImageElement(src: url);
    await img.onLoad.first;
    final w = img.naturalWidth, h = img.naturalHeight;
    final k = w > h ? _maxSide / w : _maxSide / h;
    final scale = k < 1 ? k : 1.0;
    final canvas = html.CanvasElement(
        width: (w * scale).round(), height: (h * scale).round());
    // White under transparent drawings, so they don't turn black.
    canvas.context2D
      ..fillStyle = '#ffffff'
      ..fillRect(0, 0, canvas.width!, canvas.height!)
      ..drawImageScaled(img, 0, 0, canvas.width!, canvas.height!);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    return base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
