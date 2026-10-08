import 'dart:io';

import 'package:flutter/services.dart';

/// Serves a directory of files as an asset bundle, with a generated asset manifest.
/// Lets widget tests read the bundled starter outlines without the global test bundle.
class DirAssetBundle extends CachingAssetBundle {
  DirAssetBundle(this.dir);
  final String dir; // e.g. docs/starter-outlines

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final keys = [
        for (final f in Directory(dir).listSync().whereType<File>()) '$dir/${f.uri.pathSegments.last}'
      ];
      return const StandardMessageCodec().encodeMessage({
        for (final k in keys) k: [
          {'asset': k}
        ]
      })!;
    }
    return ByteData.sublistView(await File(key).readAsBytes());
  }
}
