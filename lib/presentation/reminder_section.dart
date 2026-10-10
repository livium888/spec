import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/reminder_service.dart';
import '../domain/reminder.dart';
import 'theme/tokens.dart';

/// Settings: a daily reminder at a time the learner picks. Short, friendly, off by default.
class ReminderSection extends ConsumerStatefulWidget {
  const ReminderSection({super.key});
  @override
  ConsumerState<ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends ConsumerState<ReminderSection> {
  ReminderConfig? _config;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ref.read(reminderServiceProvider).config();
    if (mounted) setState(() => _config = c);
  }

  Future<void> _toggle(bool on) async {
    final svc = ref.read(reminderServiceProvider);
    final c = _config!;
    if (on) {
      final ok = await svc.enable(c.hour, c.minute);
      if (!ok && mounted) {
        setState(() => _note = 'Notifications are blocked for this app. Allow them in your phone\'s settings, then try again.');
      } else if (mounted) {
        setState(() => _note = null);
      }
    } else {
      await svc.disable();
      if (mounted) setState(() => _note = null);
    }
    await _load();
  }

  Future<void> _pickTime() async {
    final c = _config!;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: c.hour, minute: c.minute));
    if (t == null) return;
    await ref.read(reminderServiceProvider).setTime(t.hour, t.minute);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _config;
    if (c == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Daily reminder', style: t.titleLarge),
      const SizedBox(height: 4),
      Text(
          'One short, friendly nudge a day, around the time you choose (Android may shift it by a few minutes). '
          'If you have already finished today\'s reviews, the next one is tomorrow.',
          style: t.bodyMedium),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Remind me every day'),
        value: c.enabled,
        onChanged: _toggle,
      ),
      if (c.enabled)
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text('Around ${formatClock(c.hour, c.minute)}'),
          onPressed: _pickTime,
        ),
      if (_note != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.s),
          child: Semantics(liveRegion: true, child: Text(_note!, style: t.bodyMedium)),
        ),
      const SizedBox(height: Sp.m),
    ]);
  }
}

/// How to get into the review without opening the app first (D51). The steps are the Android ones; the names of
/// menus differ a little between phone makers, which the card says.
class FasterWaysInCard extends StatelessWidget {
  const FasterWaysInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(n, style: t.titleSmall)),
            Expanded(child: Text(text, style: t.bodyMedium)),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Faster ways in', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Open your cards without opening the app first. All of these are yours to add or ignore.', style: t.bodySmall),
          const SizedBox(height: 10),
          step('1.', 'Touch and hold the app icon: "Review now" or "Quick 5" (five cards, then stop).'),
          step('2.', 'Home screen widget: touch and hold an empty spot, choose Widgets, then Daily Learning > Cards waiting.'),
          step('3.', 'Quick Settings tile: swipe down twice, tap the pencil, and drag "Review" into your tiles.'),
          step('4.', 'The daily reminder above opens the review when you tap it.'),
          const SizedBox(height: 4),
          Text(
            'Menu names differ a little between phones. The widget and tile show how many cards are waiting for today once the app has been opened today; until then they say "tap to start".',
            style: t.bodySmall,
          ),
        ]),
      ),
    );
  }
}

