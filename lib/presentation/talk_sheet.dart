import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/talk_prompt.dart';
import 'theme/tokens.dart';

/// "Talk it through with an AI" (D60): the card, its answer and a request for a Socratic conversation, handed to
/// the AI app the learner picks. The sheet shows exactly what will be sent and lets them say where they are stuck.
/// The app itself sends nothing (Android's share sheet or the clipboard), and the schedule is untouched.
Future<void> showTalkSheet(BuildContext context, {required int noteId, int ord = 0}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TalkSheet(noteId: noteId, ord: ord),
    );

class _Loaded {
  const _Loaded(this.card, this.profile);
  final TalkCard? card;
  final String? profile;
}

class TalkSheet extends ConsumerStatefulWidget {
  const TalkSheet({super.key, required this.noteId, this.ord = 0});
  final int noteId;
  final int ord;
  @override
  ConsumerState<TalkSheet> createState() => _TalkSheetState();
}

class _TalkSheetState extends ConsumerState<TalkSheet> {
  late Future<_Loaded> _f = _load();
  final _confusion = TextEditingController();

  Future<_Loaded> _load() async {
    final s = ref.read(talkServiceProvider);
    return _Loaded(await s.load(widget.noteId, widget.ord), await s.profile());
  }

  @override
  void dispose() {
    _confusion.dispose();
    super.dispose();
  }

  String _prompt(_Loaded d) => renderTalkPrompt(d.card!, confusion: _confusion.text, learnerProfile: d.profile);

  /// Tag the note (best effort: a failed tag never stops the learner), then hand the text over.
  Future<void> _tag() async {
    try {
      await ref.read(reviewServiceProvider).markTalkedThrough(widget.noteId);
    } catch (_) {}
  }

  Future<void> _share(_Loaded d) async {
    final text = _prompt(d);
    await _tag();
    // The share result is not used: on Android it often says "unavailable" even when it worked (verify against the
    // current share_plus docs), so the tag is written when the learner taps, not when the other app confirms.
    try {
      await ref.read(promptSharerProvider).send(text, title: 'Talk through a card');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the share sheet: $e. Use Copy instead.')));
    }
  }

  Future<void> _copy(_Loaded d) async {
    final text = _prompt(d);
    await _tag();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Paste it into your AI app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FutureBuilder<_Loaded>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading the card')));
          }
          final d = snap.data;
          if (snap.hasError || d == null || d.card == null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Talk it through with an AI', style: t.titleLarge),
                const SizedBox(height: 8),
                Text(snap.hasError ? 'This card could not be read: ${snap.error}' : 'This card no longer exists.'),
                const SizedBox(height: 12),
                Row(children: [
                  if (snap.hasError) FilledButton(onPressed: () => setState(() => _f = _load()), child: const Text('Try again')),
                  if (snap.hasError) const SizedBox(width: 8),
                  TextButton(style: TextButton.styleFrom(minimumSize: const Size(64, 48)), onPressed: () => Navigator.of(context).maybePop(), child: const Text('Close')),
                ]),
              ]),
            );
          }
          final prompt = _prompt(d);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Talk it through with an AI', style: t.titleLarge),
              const SizedBox(height: 8),
              Text(
                'This sends the card, with its answer, to the AI app you pick, and asks it to question you until the card makes sense. '
                'Nothing leaves this app by itself: you choose where it goes.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confusion,
                minLines: 2,
                maxLines: 4,
                maxLength: kMaxConfusionChars,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "What's confusing you? (optional)",
                  hintText: "e.g. I don't see why the second step follows",
                ),
                onChanged: (_) => setState(() {}),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('What will be sent', style: t.titleSmall),
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.surfaceDim, borderRadius: BorderRadius.circular(12)),
                    child: SingleChildScrollView(child: SelectableText(prompt, style: t.bodySmall)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
                  onPressed: () => _share(d),
                  icon: const Icon(Icons.share),
                  label: const Text('Share to an AI app'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
                  onPressed: () => _copy(d),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                d.card!.isProblem
                    ? 'The chat stays outside this app and does not change your schedule.'
                    : 'If the AI offers a clearer version of the card, share its reply back to this app: it opens as an import preview and is added as a new card. '
                        'Then pause or delete this one. The chat does not change your schedule.',
                style: t.bodySmall?.copyWith(color: c.inkSoft),
              ),
            ]),
          );
        },
      ),
    );
  }
}
