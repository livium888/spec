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
  PhoneCheckItem('fit', 'Memory model fit',
      'Settings > Advanced > Memory model. If it is available, run it and note how long it took.'),
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
