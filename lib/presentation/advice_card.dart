import 'package:flutter/material.dart';

import '../domain/study_advisor.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// Verdict + reasons. State is conveyed by icon AND words as well as colour.
class AdviceCard extends StatefulWidget {
  const AdviceCard(this.advice, {super.key, this.compact = false});
  final Advice advice;

  /// Compact: headline + one reason; the rest behind "Why?".
  final bool compact;

  static (IconData, String) style(AdviceLevel l) => switch (l) {
        AdviceLevel.go => (Icons.check_circle_outline, 'Good time'),
        AdviceLevel.gentle => (Icons.speed, 'Go gently'),
        AdviceLevel.wait => (Icons.pause_circle_outline, 'Hold off'),
        AdviceLevel.stop => (Icons.bedtime_outlined, 'Done for today'),
      };

  @override
  State<AdviceCard> createState() => _AdviceCardState();
}

class _AdviceCardState extends State<AdviceCard> {
  bool _open = false;

  (Color tint, Color strong) _colors(AppColors c) => switch (widget.advice.level) {
        AdviceLevel.go => (c.goodTint, c.good),
        AdviceLevel.gentle => (c.infoTint, c.info),
        AdviceLevel.wait => (c.warnTint, c.warn),
        AdviceLevel.stop => (c.surfaceDim, c.inkSoft),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final a = widget.advice;
    final (icon, label) = AdviceCard.style(a.level);
    final (tint, strong) = _colors(c);
    final reasons = a.reasons;
    final shown = widget.compact ? (_open ? reasons : reasons.take(1).toList()) : reasons;
    final hasMore = widget.compact && reasons.length > 1;
    return SoftCard(
      color: tint,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          container: true,
          label: '$label. ${a.headline}',
          child: ExcludeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: strong, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: strong, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(a.headline, style: t.titleSmall),
                ]),
              ),
            ]),
          ),
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(widget.compact && !_open ? r : '• $r', style: t.bodySmall?.copyWith(color: c.ink)),
            ),
        ],
        if (hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: strong, minimumSize: const Size(48, 32), tapTargetSize: MaterialTapTargetSize.padded, padding: EdgeInsets.zero),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Hide' : 'Why?'),
            ),
          ),
      ]),
    );
  }
}
