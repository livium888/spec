import 'package:flutter/material.dart';

import '../domain/study_advisor.dart';

/// Verdict + reasons. State is conveyed by icon AND words, never colour alone.
class AdviceCard extends StatelessWidget {
  const AdviceCard(this.advice, {super.key, this.compact = false});
  final Advice advice;

  /// Compact: headline + one reason; the rest behind "Why?".
  final bool compact;

  static (IconData, String) _style(AdviceLevel l) => switch (l) {
        AdviceLevel.go => (Icons.check_circle_outline, 'Good time'),
        AdviceLevel.gentle => (Icons.speed, 'Go gently'),
        AdviceLevel.wait => (Icons.pause_circle_outline, 'Hold off'),
        AdviceLevel.stop => (Icons.bedtime_outlined, 'Done for today'),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, label) = _style(advice.level);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            container: true,
            label: '$label. ${advice.headline}',
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.labelMedium),
                  Text(advice.headline, style: t.titleSmall),
                ]),
              ),
            ]),
          ),
          if (advice.reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (compact)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(advice.summary, style: t.bodyMedium),
                subtitle: const Text('Why?'),
                children: [
                  for (final r in advice.reasons.skip(1))
                    Align(alignment: Alignment.centerLeft, child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $r'),
                    )),
                ],
              )
            else
              for (final r in advice.reasons)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $r')),
          ],
        ]),
      ),
    );
  }
}
