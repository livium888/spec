/// The phone check: things to try on a real device, and the report to send back.
/// Plain data and text; no Flutter, no I/O.
library;

enum CheckState { untested, works, broken }

class PhoneCheckItem {
  const PhoneCheckItem(this.id, this.title, this.how);
  final String id, title, how;
}

const kPhoneCheck = <PhoneCheckItem>[
  PhoneCheckItem('install', 'New version installed over the old one',
      'You did not have to uninstall, and your cards are still there.'),
  PhoneCheckItem('review', 'Review a few cards', 'Tap a card to flip it, rate it, finish a short session, try Undo.'),
  PhoneCheckItem('learn', 'Learn something new gives a prompt',
      'Tap it, then "Copy prompt". Paste into any notes app to see that it copied.'),
  PhoneCheckItem('share_out', 'Send prompt to my AI app',
      'On the prompt screen tap "Send to my AI app", pick your AI. The prompt should appear ready to send.'),
  PhoneCheckItem('paste_cards', 'Paste cards from your AI',
      'Copy the AI\'s JSON answer, "Paste the answer" > "Paste from clipboard", check the preview, import.'),
  PhoneCheckItem('share_in', 'Share an answer into this app',
      'In your AI app, share/send its answer to "Daily Learning". The preview should open by itself.'),
  PhoneCheckItem('paste_topics', 'Paste a topic list', 'From a "more topics" prompt.'),
  PhoneCheckItem('paste_subjects', 'Paste new subjects', 'From a "new subjects" prompt: tick some, add them.'),
  PhoneCheckItem('other_ai', 'An answer from a different AI',
      'Try ChatGPT, Gemini or DeepSeek if you use them. Note which one in the report.'),
  PhoneCheckItem('backup', 'Backup to a folder',
      'Settings > Choose folder > Back up now. A "learning-backup-….db.gz" file should appear in that folder.'),
  PhoneCheckItem('restore', 'Restore the latest backup', 'Settings > Restore latest. Counts should match what you had.'),
  PhoneCheckItem('edit_delete', 'Edit and delete a card', 'Library > Browse. Change a word and save; delete one.'),
  PhoneCheckItem('fit', 'Scheduling tune',
      'Settings > Advanced > Tune my scheduling. If it is available, run it and note how long it took.'),
  PhoneCheckItem('plan', 'Looking ahead',
      'Library > Advanced > Looking ahead: the table appears within a few seconds and the slider changes the numbers.'),
  PhoneCheckItem('retire', 'Retire and bring back cards',
      'Library > Advanced > Retire mastered cards. If some qualify, retire them, then bring one back.'),
  PhoneCheckItem('picture', 'Picture on a card',
      'Edit a card > Add a picture. It shows on the question or answer in a review; tap it for full screen. Back up and restore: it is still there.'),
  PhoneCheckItem('find_picture', 'Find a picture online',
      'Edit a card > Find a picture online. Allow it, search (try "Mona Lisa"), open a result, use it. The credit shows under the picture in a review. Then switch airplane mode on and search again: a clear "could not reach" message, no crash.'),
  PhoneCheckItem('keywords', 'Image keywords for older cards',
      'Library > Image keywords for older cards. Send the prompt to your AI, share its answer back (or paste it), check the preview, add. Then edit one of those cards: the Image keywords box is filled in.'),
  PhoneCheckItem('reading', 'Reading list',
      'Import cards from an AI (prompt v9). Library > Go deeper: suggestions appear. Tap Check it exists (agree), see Listed in Open Library, then Look it up: a tab opens over the app and Back returns to the list.'),
  PhoneCheckItem('review_extras', 'Undo bar and about this card',
      'In a review answer a card: a bar "Rated ... Undo" appears for a few seconds; tap Undo, the card returns. Tap the state tag (New, Learning, Review): the sheet shows the numbers and the curve. Rate a new card Good, then keep reviewing until nothing else is due: the card from a minute ago waits; one from 2+ minutes ago appears early.'),
  PhoneCheckItem('foundations', 'Build the foundations',
      'In a review tap the state tag, then Build the foundations. Send the prompt to your AI, share its answer back, add the cards. Next review: those cards come first. Tap the tag on the original card: it says Foundations added.'),
  PhoneCheckItem('math', 'Formulas and Markdown in cards',
      'Learn something new in a maths, physics or chemistry subject. In the review the formulas are drawn (not dollar signs and backslashes) and bold or bullets look right. Edit a card: the preview shows the same. Note any formula that shows as code.'),
  PhoneCheckItem('problems', 'Problem cards',
      'In a maths or physics subject choose Learn something new, or set a topic to Problems (Subjects and topics, the menu on the topic). Import: the preview says Arithmetic checked. Review: the worked example comes first; levels 2 to 4 come on later days with steps hidden. Try Show next step and Show solution.'),
  PhoneCheckItem('map', 'Knowledge map',
      'Library > a subject > the map icon at the top. Topics appear as tiles with their prerequisites above; Next up lists what is ready; tap a topic: the sheet shows the state in words. Switch to List: same facts. Pinch to zoom the map.'),
  PhoneCheckItem('numbers', 'Today and Progress numbers',
      'Progress > Your memory: add the legend counts (New, Learning, Growing, Fading, Long-term, Retired, Paused): they equal the card count above the bar. Retire some cards (Library > Retire): "in long-term memory" does not drop. Today: answer a new card three times: the ring counts it once. After midnight but before 4 am the weekday letters and the forecast still show the day before.'),
  PhoneCheckItem('anki', 'Import from Anki',
      'In Anki: File > Export > Anki Deck Package, tick "Support older Anki versions". Library > Import from Anki > Choose a file. The plan lists your top-level decks with counts; rename or untick one, import. Open the subject: cards, pictures, bold and formulas look right; Today shows them as new, a few a day. Import the same file again: nothing is added. Also try a .txt export (Notes in Plain Text) and a deck exported WITHOUT the older-versions tick: the message says how to export again.'),
  PhoneCheckItem('entries', 'Faster ways in',
      'Touch and hold the app icon: Review now and Quick 5 are there; each opens the review straight away (also when the app was closed). Add the widget (home screen > Widgets > Daily Learning): it shows the cards waiting; tap it for the review, tap Quick 5 for five cards. Add the Review tile (swipe down twice > pencil): it shows the count; tap it. Turn the reminder on and tap it when it arrives: the review opens. Do five cards in Quick 5: "That was your 5" appears with Keep going. Next day, before opening the app: the widget and tile say tap to start, not yesterday\'s number.'),
  PhoneCheckItem('words', 'Words and the review menu',
      'In a review the tag on the card says Growing, Long-term, Fading, Learning or New (tap it for the explanation: same word). Progress uses the same words in the legend. The top bar has Close, progress, Undo and a three-dot menu: Mark, Edit or delete, About this card, and Pause this card below a line. Pause a card: a message offers Undo; Library > Browse cards > Paused only lists it and Bring back returns it. Settings has "Tune my scheduling".'),
  PhoneCheckItem('tomorrow', 'Tomorrow card',
      'Progress > Coming up > Tomorrow: reviews due equals the chart\'s tomorrow bar; new cards equals your daily limit (or fewer if fewer wait); the minutes and the verdict follow your study-time budget (Settings). Compare with the other app\'s count for the same cards and tell me both numbers.'),
  PhoneCheckItem('agree', 'Progress agrees with Today',
      'Open Today and note the number of cards. Progress > Coming up > Tomorrow > Still to do today: "due now" plus "new cards for today" is that same number, and each subject tile\'s "N due" adds up to Today\'s due cards. Finish today, then read the Tomorrow card\'s reviews (ordinary plus problem). Tomorrow at 7: Today\'s Learning + Due (not the headline, which adds new cards) is that number, plus anything you left undone.'),
  PhoneCheckItem('pause', 'Pause before apps',
      'Settings > Focus before apps: LinkedIn and *.linkedin.com are suggested. Open accessibility settings and switch on "Daily Learning: pause before apps" (if Android says it is restricted: App info, three dots, Allow restricted settings, then again). Open LinkedIn: the pause appears at once. Try Not now (home screen), Breathe then open (10 s, then LinkedIn for 2 min; after 2 min the pause comes back), and Do 5 cards (5 answers, then "Back to LinkedIn"). In Chrome open linkedin.com: the pause appears; a search for linkedin in the bar does not. Not now leaves the tab open: opening Chrome again shows the pause (breathe, then close the tab). Tell us which browsers did not pause.'),
  PhoneCheckItem('pause2', 'Pause: growing wait, limit, counts',
      'Settings > Focus before apps > Test the pause: the real pause shows, with your next card\'s question in a box. Open LinkedIn three times, choosing Not now each time: the second time the breathe button says 15 s, the third 20 s. Set the daily open limit to 1, breathe and open once, leave, open again: only Do 5 cards and Not now remain. Progress shows a Pause before apps card with today\'s attempts; Today shows this week\'s line. Switch the service off in Android: Today warns that the pause is off.'),
  PhoneCheckItem('talk', 'Talk it through with an AI',
      'In a review, before showing the answer, open the menu (three dots) > Talk it through with an AI: the answer is now shown, and the sheet previews the text that will be sent. Type what confuses you: it appears in the preview. Tap Share to an AI app and choose your AI app: it opens with the whole text. Check the AI starts with one short question and does not explain first. At the end ask for a clearer card: the reply is one JSON card. Try sharing just that message back to Daily Learning (it opens as an import preview); if your AI app only shares a link, copy the reply and use Library > Paste an answer. Tell us which AI app worked. Later, Library > Browse cards > that card > the speech-bubble icon works too. Forget a card twice with Again: the bar shows Talk it through.'),
  PhoneCheckItem('move', 'Move first',
      'Settings > Focus before apps > Move first: the suggestions are listed; remove one, add one (try 5 seconds: it is refused), use the suggestions. Open LinkedIn: the pause has a Move first button. Pick an exercise: a countdown runs and the open button appears at zero; leave the phone face-up and watch the screen stay on for a 60-second plank (does it dim or lock?). Open it: LinkedIn is free for the free minutes, Instagram or another paused app is not. Set the daily open limit to 1, move once, then open LinkedIn again: no Move first, no Breathe. Progress today line: Ways in today: 0 by cards, 1 by exercise, 0 by breathing.'),
  PhoneCheckItem('focus', 'Focus before apps: cards come first, editing',
      'Settings, near the top: a Focus before apps heading and a card that says On (or Off) and what is chosen; tap it. The screen has three groups: What to pause, Ways out, Harder to open, and Test the pause under the status card. Under Move first tap an exercise: change its name and time, Save; it keeps its place. Use the arrows to reorder; open the pause with Test the pause: the exercises are listed in that order (if it offers only the cards, you have already got in twice today by breathing or exercise: set Cards come first to Off for this step). Remove one: an Undo bar appears and stays until you close it; Undo puts it back where it was. Ways out > Cards come first is at 2 openings. Open LinkedIn and get in twice by breathing or an exercise (not by cards), then open it a third time: the pause says why it is cards this time and offers only Do 5 cards and Not now. Do 5 cards and finish: LinkedIn opens; next time Breathe and Move first are back. Set it to Off: they are always there. Progress, Focus before apps card: tap it to open the settings; today\'s line says Ways in today with cards, exercise and breathing counts.'),
  PhoneCheckItem('speech', 'Read aloud',
      'Subjects and topics > Read cards aloud: pick a language. In a review tap the speaker. If there is no voice, the message says how to install one.'),
  PhoneCheckItem('reminder', 'Daily reminder', 'Turn it on, set a time two minutes ahead, wait for it, tap it.'),
  PhoneCheckItem('display', 'Dark mode and large text',
      'Switch the phone to dark mode and the biggest text size: nothing is cut off or unreadable.'),
];

String renderReport({
  required String build,
  required String os,
  required Map<String, String> facts,
  required Map<String, CheckState> checks,
  required String notes,
  required String errorLogTail,
}) {
  final b = StringBuffer()
    ..writeln('Daily Learning report')
    ..writeln(build)
    ..writeln(os);
  for (final e in facts.entries) {
    b.writeln('${e.key}: ${e.value}');
  }
  b.writeln('\nPhone check');
  for (final i in kPhoneCheck) {
    final s = checks[i.id] ?? CheckState.untested;
    b.writeln('[${switch (s) { CheckState.works => 'works', CheckState.broken => 'BROKEN', CheckState.untested => 'not tried' }}] ${i.title}');
  }
  if (notes.trim().isNotEmpty) b.writeln('\nNotes\n${notes.trim()}');
  b.writeln('\nError log (newest last)');
  b.writeln(errorLogTail.trim().isEmpty ? '(no errors recorded)' : errorLogTail.trim());
  return b.toString();
}
