import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'add_card_screen.dart';
import 'anki_import_screen.dart';
import 'browse_cards_screen.dart';
import 'home_screen.dart';
import 'import_screen.dart';
import 'keywords_screen.dart';
import 'new_subject_screen.dart';
import 'plan_ahead_screen.dart';
import 'prompt_screen.dart';
import 'reading_screen.dart';
import 'retire_screen.dart';
import 'starter_library_screen.dart';
import 'subjects_screen.dart';
import 'theme/tokens.dart';
import 'topics_screen.dart';
import 'widgets/soft_card.dart';

/// Everything you manage: subjects and topics, plus the ways to bring cards in.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _go(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    ref.read(refreshProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final data = ref.watch(homeDataProvider);
    Widget action(IconData icon, String title, String sub, Widget page) => Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: SoftCard(
            onTap: () => _go(context, ref, page),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleSmall),
                  Text(sub, style: t.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right, color: c.inkSoft),
            ]),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        Text('Library', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Tap a subject to see its topics and choose what to learn. Below: every way to add to your library.', style: t.bodySmall),
        const SectionTitle('Subjects'),
        data.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Could not load: $e'),
          data: (d) => d.stats.subjects.isEmpty
              ? const SoftCard(child: Text('No subjects yet. Add some from the starter library below.'))
              : GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: Sp.m,
                  crossAxisSpacing: Sp.m,
                  childAspectRatio: 1.05,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final s in d.stats.subjects)
                      SubjectTile(s, width: double.infinity, onTap: () => _go(context, ref, TopicsScreen(domainId: s.domainId))),
                  ],
                ),
        ),
        const SectionTitle('Add to your library'),
        action(Icons.library_books_outlined, 'Starter library', 'Ready-made subjects with ordered topics', const StarterLibraryScreen()),
        action(Icons.content_paste, 'Paste an answer', 'Import cards or an outline from your LLM', const ImportScreen()),
        action(Icons.add_circle_outline, 'New subject or more topics', 'Get an outline prompt for anything', const NewSubjectScreen()),
        action(Icons.edit_note, 'Custom prompt', 'Make cards from your own source text', const PromptScreen()),
        action(Icons.add_card, 'Add a card', 'Write a single card yourself', const AddCardScreen()),
        action(Icons.move_to_inbox_outlined, 'Import from Anki', 'Bring in a deck (.apkg) or a text export', const AnkiImportScreen()),
        const SectionTitle('Manage'),
        action(Icons.search, 'Browse, edit or delete cards', 'Find any card you have', const BrowseCardsScreen()),
        action(Icons.menu_book_outlined, 'Go deeper: reading list', 'Books and articles your AI suggested for your topics', const ReadingScreen()),
        action(Icons.image_search, 'Image keywords for older cards', 'Ask your AI for the words Find a picture searches with', const KeywordsScreen()),
        action(Icons.tune, 'Subjects and topics', 'Choose what is offered, and how well to remember each subject', const SubjectsScreen()),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Advanced', style: t.titleMedium),
            subtitle: const Text('Planning ahead and retiring cards'),
            children: [
              action(Icons.trending_up, 'Looking ahead', 'How much review time your library will need in the coming years', const PlanAheadScreen()),
              action(Icons.archive_outlined, 'Retire mastered cards', 'Stop reviewing what you have known for years', const RetireScreen()),
            ],
          ),
        ),
      ]),
    );
  }
}
