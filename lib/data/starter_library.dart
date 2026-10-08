import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/outline_parser.dart';

const kStarterDir = 'docs/starter-outlines/';

/// One bundled subject outline.
class StarterOutline {
  const StarterOutline({
    required this.asset,
    required this.domain,
    required this.topics,
    required this.cards,
    required this.askName,
    required this.raw,
  });
  final String asset, domain, raw;
  final int topics, cards;

  /// Template subjects (e.g. a language course) need the learner to name them.
  final bool askName;

  /// Same outline under a different subject name, without the template flag.
  String rawAs(String name) {
    final m = jsonDecode(raw) as Map<String, dynamic>..remove('ask_name');
    m['domain'] = name.trim();
    return jsonEncode(m);
  }
}

/// Loads the subjects bundled with the app. Works fully offline.
class StarterLibrary {
  static Future<List<StarterOutline>> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final paths = manifest
        .listAssets()
        .where((a) => a.startsWith(kStarterDir) && a.endsWith('.json'))
        .toList()
      ..sort();
    final out = <StarterOutline>[];
    for (final path in paths) {
      final raw = await b.loadString(path);
      final p = parseOutlineJson(raw);
      if (p.hasFatal) continue; // never show a broken bundled file
      final j = jsonDecode(raw) as Map<String, dynamic>;
      out.add(StarterOutline(
        asset: path,
        domain: p.domain,
        topics: p.items.length,
        cards: p.items.fold<int>(0, (n, i) => n + i.targetCards),
        askName: j['ask_name'] == true,
        raw: raw,
      ));
    }
    return out;
  }
}
