import 'dart:typed_data';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

/// A picture chosen from the phone's gallery, already shrunk.
class PickedImage {
  const PickedImage(this.bytes);
  final Uint8List bytes;
}

/// Choosing a picture. The system photo picker is used, so the app needs no storage permission.
abstract class ImagePickerService {
  Future<PickedImage?> pick();
}

class GalleryImagePicker implements ImagePickerService {
  const GalleryImagePicker();
  @override
  Future<PickedImage?> pick() async {
    // Shrunk by the platform while picking: at most 1,280 px and JPEG quality 80 keeps a picture
    // to roughly 100-300 KB, which matters because pictures travel inside every backup.
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (f == null) return null;
    return PickedImage(await f.readAsBytes());
  }
}

/// Reading text aloud with the phone's own text-to-speech voices (offline once a voice is installed).
abstract class Speaker {
  /// Speak [text] in [language] (BCP-47, e.g. "es-ES"). Returns an explanation if it cannot, else null.
  Future<String?> speak(String text, String language);
  Future<void> stop();
}

class PhoneSpeaker implements Speaker {
  PhoneSpeaker();
  final _tts = FlutterTts();

  @override
  Future<String?> speak(String text, String language) async {
    try {
      final available = await _tts.isLanguageAvailable(language);
      if (available == false || available == 0) {
        return 'This phone has no voice for $language. Install one in Settings > System > Languages > Text-to-speech.';
      }
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(0.45);
      await _tts.stop();
      await _tts.speak(text);
      return null;
    } catch (e) {
      return 'Could not read this aloud: $e';
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Languages offered for reading aloud: name and BCP-47 code.
const kSpeechLanguages = <(String, String)>[
  ('English (UK)', 'en-GB'),
  ('English (US)', 'en-US'),
  ('Spanish', 'es-ES'),
  ('French', 'fr-FR'),
  ('German', 'de-DE'),
  ('Italian', 'it-IT'),
  ('Portuguese', 'pt-PT'),
  ('Romanian', 'ro-RO'),
  ('Dutch', 'nl-NL'),
  ('Swedish', 'sv-SE'),
  ('Polish', 'pl-PL'),
  ('Russian', 'ru-RU'),
  ('Greek', 'el-GR'),
  ('Turkish', 'tr-TR'),
  ('Arabic', 'ar-SA'),
  ('Hindi', 'hi-IN'),
  ('Japanese', 'ja-JP'),
  ('Korean', 'ko-KR'),
  ('Chinese (Mandarin)', 'zh-CN'),
];
