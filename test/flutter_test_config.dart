import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load the real fonts for every test so layouts (and screenshots) match a device,
/// instead of flutter_test's default square "Ahem" glyphs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> load(String family, String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
  }

  await load('Inter', 'assets/fonts/Inter-Variable.ttf');
  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  final mf = '$root/bin/cache/artifacts/material_fonts';
  await load('MaterialIcons', '$mf/MaterialIcons-Regular.otf');
  await load('Roboto', '$mf/Roboto-Regular.ttf');
  await testMain();
}
