import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/card_edit_service.dart';
import '../data/media_service.dart' show MediaException, MediaService;
import '../data/settings_repo.dart';
import '../domain/commons.dart' show cleanImageQuery, kMaxImageQueryChars;
import '../domain/card_markup.dart';
import 'card_picture.dart';
import 'find_picture_screen.dart';
import 'widgets/rich_card_text.dart';

/// What happened on the edit screen, so callers can reload.
enum EditOutcome { saved, deleted }

/// Edit a card's text, or delete it permanently.
class EditCardScreen extends ConsumerStatefulWidget {
  const EditCardScreen({super.key, required this.noteId});
  final int noteId;
  @override
  ConsumerState<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends ConsumerState<EditCardScreen> {
  static const _labels = {
    'front': 'Question',
    'back': 'Answer',
    'cloze': 'Text with gaps, like {{c1::answer}}',
    'why_it_matters': 'Why it matters (optional)',
    'example': 'Example (optional)',
    'memory_hook': 'Memory hook (optional)',
  };
  final _ctl = <String, TextEditingController>{};
  NoteRow? _note;
  String? _image, _originalImage, _newImage; // SHA-256s: current, as loaded, picked in this session
  String _imageSide = 'front';
  final _alt = TextEditingController();
  final _keywords = TextEditingController(); // words to find a picture with: the AI's image_query, editable, kept on the card
  String _credit = ''; // who made a picture found online; empty for the learner's own photos
  late final MediaService _media;
  bool _saved = false;
  bool _loading = true, _saving = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    _media = ref.read(mediaServiceProvider);
    _load();
  }

  Future<void> _load() async {
    final n = await ref.read(cardEditServiceProvider).note(widget.noteId);
    if (!mounted) return;
    if (n != null) {
      final keys = n.type == 'cloze'
          ? ['cloze', 'back', 'why_it_matters', 'example', 'memory_hook']
          : ['front', 'back', 'why_it_matters', 'example', 'memory_hook'];
      for (final k in keys) {
        _ctl[k] = TextEditingController(text: n.fields[k] as String? ?? '');
      }
    }
    if (n != null) {
      _image = _originalImage = n.fields['image'] as String?;
      // A picture shown with the question can give the answer away, so the answer side is the default;
      // the AI's hint (or the learner) can still put it on the question.
      _imageSide = (n.fields['image_side'] as String?) == 'front' ? 'front' : 'back';
      _alt.text = n.fields['image_alt'] as String? ?? '';
      _credit = n.fields['image_credit'] as String? ?? '';
      _keywords.text = n.fields['image_query'] as String? ?? '';
    }
    setState(() {
      _note = n;
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ref.read(imagePickerProvider).pick();
      if (picked == null) return;
      final sha = await _media.save(picked.bytes);
      // A picture picked now and then abandoned is cleaned up when the screen closes.
      if (_newImage != null && _newImage != sha && _newImage != _originalImage) await _media.deleteIfOrphan(_newImage);
      if (mounted) setState(() { _image = sha; _newImage = sha; _credit = ''; _errors = const []; });
    } on MediaException catch (e) {
      if (mounted) setState(() => _errors = [e.message]);
    } catch (e) {
      if (mounted) setState(() => _errors = ['Could not open the picture: $e']);
    }
  }

  /// What to search for: only the AI's `image_query` hint. A guess from the question text gave
  /// nonsense ("According to E"), so without a hint the box starts empty for the learner to fill.
  String _suggestedQuery() => cleanImageQuery(_keywords.text) ?? '';

  /// The first online step in the app, so it asks once and says exactly what leaves the phone.
  Future<bool> _consentToOnline() async {
    final settings = ref.read(settingsRepoProvider);
    if (await settings.get(SettingsRepo.onlinePictures) == SettingsRepo.onlinePicturesAgreed) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Look for a picture online?'),
        content: const Text(
          'This is the one place the app goes online, and only when you tap Find a picture. '
          'It sends your search words (and your phone\'s internet address, as any website visit does) to '
          'four free picture libraries: Wikimedia Commons, Openverse, the Metropolitan Museum of Art and the '
          'Art Institute of Chicago. Nothing else leaves your phone: no cards, no history. '
          'The picture you pick is saved on your phone with its credit. You can turn this off in Settings.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
        ],
      ),
    );
    if (ok != true) return false;
    await settings.set(SettingsRepo.onlinePictures, SettingsRepo.onlinePicturesAgreed);
    return true;
  }

  Future<void> _findPicture() async {
    if (!await _consentToOnline() || !mounted) return;
    final found = await Navigator.of(context).push<FoundPicture>(
        MaterialPageRoute(builder: (_) => FindPictureScreen(initialQuery: _suggestedQuery())));
    if (found == null || !mounted) return;
    try {
      final sha = await _media.save(found.bytes);
      if (_newImage != null && _newImage != sha && _newImage != _originalImage) await _media.deleteIfOrphan(_newImage);
      if (!mounted) return;
      setState(() {
        _image = sha;
        _newImage = sha;
        _credit = found.credit;
        _errors = const [];
      });
    } on MediaException catch (e) {
      if (mounted) setState(() => _errors = [e.message]);
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _alt.dispose();
    _keywords.dispose();
    final abandoned = _newImage;
    if (!_saved && abandoned != null && abandoned != _originalImage) {
      _media.deleteIfOrphan(abandoned).ignore(); // picked but never saved
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final errors = await ref.read(cardEditServiceProvider).update(widget.noteId, {
      for (final e in _ctl.entries) e.key: e.value.text,
      'image': _image ?? '',
      'image_side': _imageSide, // kept without a picture too: it is where a picture will go
      'image_query': _keywords.text,
      'image_alt': _image == null ? '' : _alt.text,
      'image_credit': _image == null ? '' : _credit,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = errors;
    });
    if (errors.isEmpty) {
      _saved = true;
      ref.read(refreshProvider.notifier).bump();
      Navigator.of(context).pop(EditOutcome.saved);
    }
  }

  Future<void> _delete() async {
    final n = _note!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: Text(
          '${n.cardCount > 1 ? 'This removes all ${n.cardCount} cards made from this text' : 'This removes the card'}'
          '${n.reviewCount > 0 ? ' and its ${n.reviewCount} review${n.reviewCount == 1 ? '' : 's'} of history' : ''}'
          ' for good. If you only want a break from it, use Suspend while reviewing instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cardEditServiceProvider).delete(widget.noteId);
    if (!mounted) return;
    ref.read(refreshProvider.notifier).bump();
    Navigator.of(context).pop(EditOutcome.deleted);
  }

  Widget _pictureSection(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Picture (optional)', style: t.labelLarge),
      const SizedBox(height: 8),
      TextField(
        controller: _keywords,
        maxLength: kMaxImageQueryChars,
        decoration: const InputDecoration(
          labelText: 'Image keywords',
          helperText: 'Used by Find a picture. They stay on the card even if you never add a picture.',
          helperMaxLines: 2,
          counterText: '',
        ),
      ),
      const SizedBox(height: 8),
      if (_image != null) ...[
        CardPicture(sha: _image!, alt: _alt.text, credit: _credit, maxHeight: 180),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'front', label: Text('Shows on the question')),
            ButtonSegment(value: 'back', label: Text('Shows on the answer')),
          ],
          selected: {_imageSide},
          onSelectionChanged: (v) => setState(() => _imageSide = v.first),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _alt,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Describe the picture (read out by screen readers)'),
        ),
      ],
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_image == null ? 'Add a picture' : 'Change the picture'),
          onPressed: _pickImage,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.travel_explore),
          label: const Text('Find a picture online'),
          onPressed: _findPicture,
        ),
        if (_image != null)
          TextButton(
              onPressed: () => setState(() {
                    _image = null;
                    _credit = '';
                  }),
              child: const Text('Remove the picture')),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final n = _note;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit card'),
        actions: [
          if (n != null)
            IconButton(tooltip: 'Delete card', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : n == null
                ? const Center(child: Text('This card no longer exists.'))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(n.domainName, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                        r'Formulas go between dollar signs, like $x^2$. You can also use **bold**, *italic*, `code` and lines starting with "- ".',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    for (final e in _ctl.entries) ...[
                      TextField(
                        controller: e.value,
                        minLines: e.key == 'back' || e.key == 'front' || e.key == 'cloze' ? 2 : 1,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(labelText: _labels[e.key]),
                      ),
                      // A preview appears only when the text has formatting or formulas in it.
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: e.value,
                        builder: (context, v, _) {
                          if (isPlainMarkup(parseCardMarkup(v.text))) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Semantics(
                              container: true,
                              label: 'Preview of ${_labels[e.key]}',
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: RichCardText(v.text, style: Theme.of(context).textTheme.bodyLarge ?? const TextStyle()),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _pictureSection(context),
                    const SizedBox(height: 12),
                    if (_errors.isNotEmpty)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_errors.join('\n'),
                              style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _saving ? null : _save,
                      child: const Text('Save changes'),
                    ),
                    const SizedBox(height: 8),
                    Text('Editing the words never changes when the card is due.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
      ),
    );
  }
}
