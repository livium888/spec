import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// "How it works": the whole loop in plain words, written to match what the app really does.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);

    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(top: Sp.l, bottom: Sp.s),
          child: Semantics(header: true, child: Text(s, style: t.titleLarge)),
        );
    Widget para(String s) => Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: Text(s, style: t.bodyMedium));
    Widget step(int n, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
              child: Text('$n', style: t.labelLarge?.copyWith(color: c.accent)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(s, style: t.bodyMedium)),
          ]),
        );
    Widget kind(String title, String body, String starts) => Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: t.bodyMedium),
              const SizedBox(height: 4),
              Text(starts, style: t.bodySmall),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('How it works')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
          heading('The idea'),
          para('This app remembers things for you, for years. It does not write cards itself: your own AI '
              '(Claude, ChatGPT, Gemini, DeepSeek, any of them) does that. The app decides what to ask it for, '
              'keeps every card, and schedules each review at the moment you are about to forget. Everything stays on your phone; '
              'the app never goes online.'),
          heading('Every day: two things'),
          step(1, 'Tap the big button on Today (it says Start review, or Keep going once you have started). A few minutes. This is what makes things stick.'),
          step(2, 'When you have the energy, tap "Learn something new". The app picks the subject and topic for you, '
              'and tells you why. You never have to choose.'),
          para('Tired, or a busy day? Do only the reviews. The app tells you when it is a good time to add more and when to stop.'),

          heading('Learn something new, step by step'),
          step(1, 'Tap "Learn something new". You get a prompt.'),
          step(2, 'Tap "Copy prompt".'),
          step(3, 'Open your AI app, paste, send.'),
          step(4, 'When it answers, copy the whole answer. It is a block of text that starts with { and ends with }.'),
          step(5, 'Back in this app tap "Paste the answer", then "Paste from clipboard". You see a preview of what will be added. '
              'Untick anything you do not want, then confirm.'),
          para('The new cards join your reviews. That is all.'),

          heading('Three kinds of prompt'),
          para('"Learn something new" gives you whichever the app needs. The prompt screen says what to expect.'),
          kind('Cards', 'Cards for one topic: a question and a short answer, plus why it matters, an example and sometimes a memory hook.',
              'The answer starts with {"domain": … "cards": […]'),
          kind('A list of topics', 'More topics for a subject you have used up. Each is a small lesson that later gets its own cards. '
              'Every batch leans a different way: deeper, practical, people and history, and so on.',
              'The answer starts with {"domain": … "items": […]'),
          kind('New subjects', 'Every third time, the app asks for entirely new subjects. The prompt tells your AI what you already study '
              '(subject names and topic titles, never your cards or your answers) so it can propose what is missing. '
              'You see each proposed subject and tick the ones you want.',
              'The answer starts with {"subjects": […]'),

          heading('How the library grows'),
          para('You start with 15 subjects, ready to go. When a subject has no topics left, the next "Learn something new" asks for more of them. '
              'Every third time it asks for new subjects. So the library has no end, and you never have to think of what to learn next.'),
          para('Finished topics come back later for a deeper round of new cards: after a few months, then a year, then longer. '
              'Nothing is used up.'),
          para('You are always in charge. In Settings > Subjects and topics you can raise a subject\'s priority, pause it, skip a topic, '
              'or choose when finished topics return. Library has more ways to add things yourself: the starter library, '
              'your own subject, your own text, or a single card.'),

          heading('Fixing and removing cards'),
          para('While reviewing, tap the pencil to edit or delete the card on screen. Or open Library > Browse, edit or delete cards '
              'to search for any card. Editing changes only the words, never when the card is due. Deleting is permanent and also removes that card\'s review history. '
              'To rest a card without losing it, tap the pause icon (suspend).'),

          heading('Making the cards fit you'),
          para('Settings > About you: a sentence or two (your job, your interests). It goes into the prompts so examples are about things you care about. '
              'Settings also has your daily minutes, which the app uses to decide how much new material is sensible.'),

          heading('Fitting the app to your memory'),
          para('Out of the box the app schedules reviews using averages from many learners. After about a thousand reviews it can fit its '
              'memory model to YOU, so cards come back when you personally are about to forget. Open Settings > Memory model: it tells you '
              'when to do it and why ("in 12 days", or "after 400 more reviews"), shows how well the new fit would have predicted cards it never saw, '
              'and only offers it if it is clearly better. You can go back at any time. It runs on your phone and never changes your history.'),

          heading('Backups'),
          para('Your cards live only on this phone. In Settings and backup, choose a folder once (for example in Google Drive or a folder on the phone). '
              'The app saves a compressed backup there about once a week and keeps the newest eight. To restore on a new phone, install the app, choose the same '
              'folder and tap "Restore latest". If Android stops background work, tap "Back up now" now and then.'),

          heading('If pasting fails'),
          para('• Copy only the JSON: from the first { to the last }. A ```json fence around it is fine; sentences before or after it are not.\n'
              '• "Not valid JSON" usually means the answer was cut off. Ask your AI: "continue", or ask for fewer items.\n'
              '• Some cards or topics marked invalid or duplicate are skipped; the rest still import.\n'
              '• Your AI added commentary? Reply "JSON only, no other text" and copy the new answer.'),

          heading('Your privacy'),
          para('The app has no accounts and makes no network calls. The only thing that leaves your phone is what you choose to paste into an AI: '
              'a prompt you can read in full before copying. The "new subjects" prompt includes your subject names and recent topic titles.'),
        ]),
      ),
    );
  }
}
