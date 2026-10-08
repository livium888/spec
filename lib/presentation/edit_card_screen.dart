import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/card_edit_service.dart';
import '../data/media_service.dart' show MediaException, MediaService;
import 'card_picture.dart';

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
      _imageSide = (n.fields['image_side'] as String?) == 'back' ? 'back' : 'front';
      _alt.text = n.fields['image_alt'] as String? ?? '';
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
      if (mounted) setState(() { _image = sha; _newImage = sha; _errors = const []; });
    } on MediaException catch (e) {
      if (mounted) setState(() => _errors = [e.message]);
    } catch (e) {
      if (mounted) setState(() => _errors = ['Could not open the picture: $e']);
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _alt.dispose();
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
      'image_side': _image == null ? '' : _imageSide,
      'image_alt': _image == null ? '' : _alt.text,
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
      if (_image != null) ...[
        CardPicture(sha: _image!, alt: _alt.text, maxHeight: 180),
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
        if (_image != null)
          TextButton(onPressed: () => setState(() => _image = null), child: const Text('Remove the picture')),
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
                    const SizedBox(height: 12),
                    for (final e in _ctl.entries) ...[
                      TextField(
                        controller: e.value,
                        minLines: e.key == 'back' || e.key == 'front' || e.key == 'cloze' ? 2 : 1,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(labelText: _labels[e.key]),
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
