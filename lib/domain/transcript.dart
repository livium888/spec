/// Lecture transcripts (D67): cleaning pasted text or .srt/.vtt content, cutting a long one into pieces a chat window
/// can take, and checking that a card's quote really is in the transcript. Pure Dart, no I/O.
///
/// The app has no AI. It stores the transcript, builds the prompts, and checks what the learner's AI sends back; this
/// file is the "stores" and "checks" part. A check here proves a quote is in the TRANSCRIPT, not that the transcript
/// (often an automatic caption) is right.
library;

/// Most words in one piece sent to an AI (a one-hour lecture is about 9,000 words, so two pieces).
const kChunkWords = 6000;

/// The longest transcript kept: about 65,000 words, far more than any single lecture.
const kMaxTranscriptChars = 400000;

/// A `[m:ss]` marker is put in at most this often, so a card can say where in the lecture it came from.
const kMarkerEverySeconds = 120;

int wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

final _cueTime = RegExp(r'^\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,]\d{1,3}');

/// "12:40", or "1:02:15" from an hour on.
String clockMarker(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '[$h:${m.toString().padLeft(2, '0')}:$ss]' : '[$m:$ss]';
}

/// Whether [raw] looks like a caption file (it has `-->` cue lines).
bool looksLikeCaptions(String raw) => RegExp(r'^\s*(?:\d{1,2}:)?\d{1,2}:\d{2}[.,]\d{1,3}\s*-->', multiLine: true).hasMatch(raw);

String _stripCueMarkup(String s) => s
    .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?::\d{2})?[.,]\d{1,3}>'), '') // <00:00:01.000> word timings
    .replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), '') // <c>, <i>, <v Speaker>
    .replaceAll(RegExp(r'\{\\[^}]*\}'), '') // {\an8}
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim();

/// Plain text from pasted text or caption content. Caption files lose their cue numbers and timings (and the repeats that
/// rolling automatic captions make), and keep a `[m:ss]` marker about every [kMarkerEverySeconds]. Plain text keeps its
/// paragraphs. Never longer than [kMaxTranscriptChars].
String cleanTranscript(String raw) {
  var text = raw.replaceAll('﻿', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (looksLikeCaptions(text)) {
    final out = StringBuffer();
    var paragraph = <String>[];
    var lastLine = '';
    var lastMarkerAt = -kMarkerEverySeconds;
    var cuesInParagraph = 0;
    var nextMarker = '';
    void flush() {
      if (paragraph.isEmpty) return;
      if (out.isNotEmpty) out.write('\n\n');
      out.write('${nextMarker.isEmpty ? '' : '$nextMarker '}${paragraph.join(' ')}');
      paragraph = [];
      nextMarker = '';
      cuesInParagraph = 0;
    }

    var inCue = false;
    for (final line in text.split('\n')) {
      final t = line.trim();
      final m = _cueTime.firstMatch(line);
      if (m != null) {
        inCue = true;
        final h = int.tryParse(m[1] ?? '0') ?? 0, mi = int.parse(m[2]!), s = int.parse(m[3]!);
        final at = h * 3600 + mi * 60 + s;
        // A new paragraph every few cues, and always where the next marker belongs.
        if (cuesInParagraph >= 8 ||
            (paragraph.isNotEmpty && RegExp(r'[.!?]$').hasMatch(paragraph.last) && cuesInParagraph >= 4) ||
            (paragraph.isNotEmpty && at - lastMarkerAt >= kMarkerEverySeconds)) {
          flush();
        }
        if (paragraph.isEmpty && at - lastMarkerAt >= kMarkerEverySeconds) {
          nextMarker = clockMarker(at);
          lastMarkerAt = at;
        }
        cuesInParagraph++;
        continue;
      }
      if (t.isEmpty) {
        inCue = false;
        continue;
      }
      if (!inCue) continue; // WEBVTT header, NOTE blocks, cue numbers and identifiers before a timing line
      final clean = _stripCueMarkup(t);
      if (clean.isEmpty || clean == lastLine) continue;
      paragraph.add(clean);
      lastLine = clean;
    }
    flush();
    text = out.toString();
  } else {
    text = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+$'), ''))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
  text = text.trim();
  return text.length > kMaxTranscriptChars ? text.substring(0, kMaxTranscriptChars).trimRight() : text;
}

/// The transcript in pieces of at most [maxWords] words, cut between paragraphs (or sentences when a paragraph is huge),
/// and balanced, so 13,000 words become three pieces of about 4,300, not 6,000 + 6,000 + 1,000. Joining the pieces with a
/// blank line gives back every word in order.
List<String> splitTranscript(String text, {int maxWords = kChunkWords}) {
  final total = wordCount(text);
  if (total <= maxWords) return [text.trim()];
  final pieces = (total / maxWords).ceil();
  final target = (total / pieces).ceil();

  // Units: paragraphs; a paragraph over half a piece is cut into sentences; a sentence over a piece is cut by words.
  final units = <String>[];
  for (final p in text.split(RegExp(r'\n\s*\n'))) {
    final t = p.trim();
    if (t.isEmpty) continue;
    if (wordCount(t) <= maxWords ~/ 2) {
      units.add(t);
      continue;
    }
    for (final s in t.split(RegExp(r'(?<=[.!?])\s+'))) {
      final st = s.trim();
      if (st.isEmpty) continue;
      if (wordCount(st) <= maxWords) {
        units.add(st);
      } else {
        final words = st.split(RegExp(r'\s+'));
        for (var i = 0; i < words.length; i += maxWords ~/ 2) {
          units.add(words.sublist(i, (i + maxWords ~/ 2).clamp(0, words.length)).join(' '));
        }
      }
    }
  }

  final chunks = <String>[];
  var current = <String>[];
  var currentWords = 0;
  for (final u in units) {
    final w = wordCount(u);
    final full = currentWords > 0 && (currentWords + w > maxWords || (currentWords >= target && chunks.length < pieces - 1));
    if (full) {
      chunks.add(current.join('\n\n'));
      current = [];
      currentWords = 0;
    }
    current.add(u);
    currentWords += w;
  }
  if (current.isNotEmpty) chunks.add(current.join('\n\n'));
  return chunks;
}

/// Lower case, only letters and digits, single spaces, no `[m:ss]` markers: the form in which quotes are compared.
String normalizeForQuote(String s) => s
    .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?::\d{2})?\]'), ' ')
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

enum QuoteCheck {
  /// In the transcript (word for word, ignoring case, punctuation and markers; or all but a few words).
  found,

  /// Not in the transcript: the AI may have paraphrased or invented it.
  notFound,

  /// Fewer than 3 words: too short to say anything.
  tooShort,
}

/// A transcript prepared once, to check many quotes against.
class QuoteIndex {
  QuoteIndex(String transcript) : _norm = ' ${normalizeForQuote(transcript)} ' {
    final words = _norm.trim().split(' ');
    for (var i = 0; i + 2 < words.length; i++) {
      _trigrams.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
    }
  }

  final String _norm;
  final _trigrams = <String>{};

  /// Exact (normalised) containment, or at least 80% of the quote's word triples present in the transcript, which allows
  /// for an AI dropping a filler word or two without letting a paraphrase through.
  QuoteCheck check(String quote) {
    final q = normalizeForQuote(quote);
    final words = q.isEmpty ? <String>[] : q.split(' ');
    if (words.length < 3) return QuoteCheck.tooShort;
    if (_norm.contains(' $q ')) return QuoteCheck.found;
    var hit = 0;
    final n = words.length - 2;
    for (var i = 0; i < n; i++) {
      if (_trigrams.contains('${words[i]} ${words[i + 1]} ${words[i + 2]}')) hit++;
    }
    return hit / n >= 0.8 ? QuoteCheck.found : QuoteCheck.notFound;
  }
}

/// Pasted or shared text that looks like a lecture (D67) rather than an AI's JSON answer: long enough, not starting like
/// JSON, and without the keys our answers carry. A wrong guess costs one tap: Add a lecture shows a preview first.
const kMinTranscriptChars = 400;
bool looksLikeTranscript(String raw) {
  final t = raw.trim();
  if (t.length < kMinTranscriptChars) return false;
  if (t.startsWith('{') || t.startsWith('[') || t.startsWith('```')) return false;
  return !RegExp(r'"(cards|primer|primers|items|subjects|domain|read_more|image_keywords)"\s*:').hasMatch(t);
}
