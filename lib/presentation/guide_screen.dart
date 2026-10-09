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
          step(2, 'Tap "Send to my AI app" and pick your AI. (Or tap "Copy prompt" and paste it there yourself.)'),
          step(3, 'Send it. When the AI answers, tap Share on its answer and choose Daily Learning. The preview opens by itself. '
              '(Or copy the answer: it is a block of text that starts with { and ends with }.)'),
          step(4, 'Copied it? Back in this app tap "Paste the answer", then "Paste from clipboard".'),
          step(5, 'You see a preview of what will be added. Untick anything you do not want, then confirm.'),
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

          heading('Pictures and reading aloud'),
          para('For art, crafts or anything visual: edit a card (the pencil in a review, or Library > Browse) and tap "Add a picture". It shows on the '
              'question or the answer, and you can tap it to see it full screen. Pictures are shrunk and kept inside the app, so they come back with every backup. '
              'Add a description so a screen reader can say what is in it.'),
          para('Or tap "Find a picture online": the app searches four free picture libraries (Wikimedia Commons, Openverse, the Met and the Art Institute of Chicago) for the words you type (every AI-written card arrives with suggested keywords, which you can edit on the card\'s edit screen; they stay on the card even if you never add a picture). Older cards have none: Library > Image keywords for older cards asks your AI for them in batches). '
              'You see the picture, who made it and its licence, and nothing is kept until you tap "Use this picture". It is then saved on your phone like any other, '
              'with its credit shown under it. This is the only thing in the app that goes online, only when you tap it, and you can switch it off in Settings.'),
          para('For languages: Settings > Subjects and topics > Read cards aloud. Pick the language and which side of your cards is written in it, then tap the '
              'speaker on a card (or switch on automatic reading). It uses your phone\'s own voices; if one is missing the message tells you how to install it. '
              'Music: pictures help for notation, but the app cannot play sounds yet.'),

          heading('Going deeper'),
          para('When you import cards for a topic, your AI may add two or three books or articles for reading more. They collect in Library > Go deeper, '
              'never in the middle of a review. They are suggestions and AIs sometimes get titles or authors wrong, so tap "Check it exists": the app asks Open Library '
              'or Crossref whether a work with that title and author is listed (this goes online, once you agree). Listed does not mean good: look at the author and '
              'the publisher. "Look it up" opens the catalogue page in a tab over the app; close it to go back to your list.'),

          heading('Formulas and formatting'),
          para('Cards can hold formulas and light formatting: **bold**, *italic*, `code`, lines starting with "- ", and maths between dollar signs, like \$x^2\$ or, for a line of its own, two dollar signs. '
              'The prompts ask your AI to use them for maths, physics and chemistry. When you edit a card, a preview shows how it will look. '
              'A formula the app cannot draw is shown as its source text, so nothing is lost.'),

          heading('A card is too hard?'),
          para('Tap the small tag at the top of a card (New, Learning, Review). The sheet explains where the card is in your memory, with numbers and a curve. '
              'If the card is hard but you like the idea, tap "Build the foundations": you get a prompt for 2 to 4 short cards on the ideas it rests on. '
              'Send it to your AI, share the answer back, and those cards come first, outside your daily limit. They teach by asking you to explain and predict, not to name terms. '
              'The hard card itself is not changed.'),

          heading('Daily reminder'),
          para('Settings > Daily reminder: one short, friendly nudge a day at the time you choose. If you have already done today\'s reviews, '
              'the next one is tomorrow. Some phones stop background reminders to save battery; if it does not appear, check the phone\'s battery settings for this app.'),

          heading('Your numbers are yours'),
          para('Settings > New cards per day is your own number, any whole number you like (10,000 if you want), and the app uses it exactly. '
              'Cards per prompt is how many cards one "Learn something new" asks your AI for (1 to 200). The advice card only advises: it never blocks you or '
              'shrinks your numbers. When you reach your own daily limit it says so and offers "Add more anyway". '
              'If you do want the limit to shrink when reviews pile up, there is a switch for that, off by default.'),

          heading('Making the cards fit you'),
          para('Settings > About you: a sentence or two (your job, your interests). It goes into the prompts so examples are about things you care about. '
              'Settings also has your daily minutes, which the app uses to decide how much new material is sensible.'),

          heading('Keeping your review time sustainable'),
          para('Every card you add costs reviews for the rest of your life, so the daily time creeps up. Library > Advanced > Looking ahead shows how much time '
              'your cards will need in 6 months, 1, 2, 5 and 10 years, lets you try different numbers of new cards a day, and tells you what pace fits your daily budget.'),
          para('Three ways to bring it down: add fewer cards a day; retire cards you have mastered (Library > Advanced > Retire mastered cards: they leave your reviews but '
              'stay in your library, and you can bring them back); or choose a lower target recall for subjects where an occasional miss is fine '
              '(Library > Subjects and topics > How much to remember).'),

          heading('Fitting the app to your memory'),
          para('Out of the box the app schedules reviews using averages from many learners. After about a thousand reviews it can fit its '
              'memory model to YOU, so cards come back when you personally are about to forget. Open Settings > Advanced > Memory model: it tells you '
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

          heading('If something goes wrong'),
          para('Settings > Advanced > Diagnostics and phone check shows which build you have, lists things to try once on your phone, and keeps a private '
              'log of crashes. Tap "Copy report" and send it to whoever maintains the app.'),

          heading('Your privacy'),
          para('The app has no accounts and makes no network calls. The only thing that leaves your phone is what you choose to paste into an AI: '
              'a prompt you can read in full before copying. The "new subjects" prompt includes your subject names and recent topic titles.'),
        ]),
      ),
    );
  }
}
