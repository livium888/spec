import 'package:flutter/material.dart';

/// A colour family for one subject. Strong-on-tint pairs are checked for AA contrast in tests.
class SubjectStyle {
  const SubjectStyle(this.strong, this.tint, this.icon);
  final Color strong, tint;
  final IconData icon;

  static const _light = [
    (Color(0xFFC2410C), Color(0xFFFFF0E6)), // terracotta
    (Color(0xFF0F766E), Color(0xFFD9F2EE)), // teal
    (Color(0xFF4338CA), Color(0xFFE4E3FB)), // indigo
    (Color(0xFF9D2A7B), Color(0xFFF8E1F1)), // plum
    (Color(0xFF166534), Color(0xFFDDF3E4)), // forest
    (Color(0xFF8A5A00), Color(0xFFFFF0CC)), // ochre
    (Color(0xFF0B6A93), Color(0xFFDDF1FA)), // sky
    (Color(0xFFBE123C), Color(0xFFFDE2E9)), // rose
    (Color(0xFF6D28D9), Color(0xFFEBE2FD)), // violet
    (Color(0xFF4D6B12), Color(0xFFE9F3CF)), // olive
  ];

  static const _dark = [
    (Color(0xFFF4A261), Color(0xFF3A2A1F)),
    (Color(0xFF5EEAD4), Color(0xFF12302D)),
    (Color(0xFFA5B4FC), Color(0xFF25264A)),
    (Color(0xFFF0ABFC), Color(0xFF3A1A33)),
    (Color(0xFF86EFAC), Color(0xFF173626)),
    (Color(0xFFFCD34D), Color(0xFF3A2F12)),
    (Color(0xFF7DD3FC), Color(0xFF12303F)),
    (Color(0xFFFDA4AF), Color(0xFF3C1B24)),
    (Color(0xFFC4B5FD), Color(0xFF2A2150)),
    (Color(0xFFBEF264), Color(0xFF2A3410)),
  ];

  static int get paletteSize => _light.length;

  static (Color, Color) pair(int index, Brightness b) {
    final list = b == Brightness.dark ? _dark : _light;
    return list[index % list.length];
  }

  /// Colour by subject id (neighbouring subjects differ), icon by what the name is about.
  static SubjectStyle of(int domainId, String name, Brightness b) {
    final (strong, tint) = pair(domainId - 1 < 0 ? 0 : domainId - 1, b);
    return SubjectStyle(strong, tint, iconFor(name));
  }

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    const rules = <(List<String>, IconData)>[
      (['think', 'decision'], Icons.psychology_alt_outlined),
      (['math', 'statistic'], Icons.functions),
      (['money', 'invest', 'financ'], Icons.savings_outlined),
      (['econom'], Icons.show_chart),
      (['business', 'strateg'], Icons.business_center_outlined),
      (['psycholog', 'influence'], Icons.forum_outlined),
      (['tech', ' ai', 'comput', 'program'], Icons.memory),
      (['history', 'power', 'politic'], Icons.account_balance_outlined),
      (['science', 'health', 'biolog', 'chem', 'physic'], Icons.biotech_outlined),
      (['philosoph', 'ethic'], Icons.balance),
      (['learning', 'effective'], Icons.school_outlined),
      (['art', 'design', 'paint'], Icons.palette_outlined),
      (['music'], Icons.music_note_outlined),
      (['craft', 'making', 'wood'], Icons.handyman_outlined),
      (['language', 'spanish', 'french', 'german', 'japanese', 'italian', 'course'], Icons.translate),
    ];
    for (final (keys, icon) in rules) {
      if (keys.any(n.contains)) return icon;
    }
    const fallback = [Icons.auto_stories_outlined, Icons.explore_outlined, Icons.lightbulb_outline, Icons.menu_book_outlined];
    return fallback[n.codeUnits.fold<int>(0, (a, b) => a + b) % fallback.length];
  }
}
