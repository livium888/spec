import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a prompt to another app through Android's share sheet (the learner picks the AI app).
/// Nothing is sent by this app itself: the share sheet is the operating system's.
abstract class PromptSharer {
  Future<void> send(String text, {String? title});
}

class SharePlusPromptSharer implements PromptSharer {
  const SharePlusPromptSharer();
  @override
  Future<void> send(String text, {String? title}) async {
    await SharePlus.instance.share(ShareParams(text: text, title: title));
  }
}

/// Text another app shared TO this one (an AI's answer). Android hands it to MainActivity,
/// which keeps it until Dart asks; it is UNTRUSTED input and only ever goes to the import preview.
abstract class ShareInbox {
  Future<String?> take();
}

class ChannelShareInbox implements ShareInbox {
  const ChannelShareInbox();
  static const _channel = MethodChannel('daily_learning/share');

  @override
  Future<String?> take() async {
    try {
      return await _channel.invokeMethod<String>('takeSharedText');
    } on MissingPluginException {
      return null; // not running on Android (tests, desktop)
    } on PlatformException {
      return null;
    }
  }
}

/// Longest shared text taken in. Larger answers are refused, not truncated into invalid JSON.
const kMaxSharedChars = 500000;
