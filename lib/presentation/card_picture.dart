import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'theme/tokens.dart';

/// A picture on a card. Tap to see it full screen and zoom. The description (if any) is what a
/// screen reader announces.
class CardPicture extends ConsumerWidget {
  const CardPicture(
      {super.key, required this.sha, this.alt = '', this.credit = '', this.maxHeight = 260, this.flush = false});
  final String sha, alt;

  /// "Author · Licence · Wikimedia Commons" for pictures found online; shown small under the picture.
  final String credit;
  final double maxHeight;

  /// Edge to edge on a soft backdrop (the top of a card), so artwork is never cropped or boxed in.
  final bool flush;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final label = alt.isEmpty ? 'Picture on the card' : alt;
    return ref.watch(mediaBytesProvider(sha)).when(
          loading: () => SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: c.accent))),
          error: (_, _) => _missing(context),
          data: (bytes) {
            if (bytes == null) return _missing(context);
            final image = Semantics(
              image: true,
              label: label,
              button: true,
              hint: 'Opens the picture full screen',
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => _FullScreen(bytes: bytes, label: label, credit: credit))),
                child: flush
                    ? SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxHeight),
                          child: Image.memory(bytes, fit: BoxFit.contain, cacheWidth: 1080, gaplessPlayback: true, excludeFromSemantics: true),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(Rd.card),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxHeight),
                          child: Image.memory(bytes, fit: BoxFit.contain, cacheWidth: 1080, gaplessPlayback: true, excludeFromSemantics: true),
                        ),
                      ),
              ),
            );
            final caption = credit.isEmpty
                ? null
                : Padding(
                    padding: EdgeInsets.fromLTRB(flush ? 16 : 2, 6, flush ? 16 : 2, flush ? 8 : 0),
                    child: Text(credit, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
            if (flush) {
              return ColoredBox(
                color: c.surfaceDim,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [image, ?caption]),
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [image, ?caption]);
          },
        );
  }

  Widget _missing(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(Icons.broken_image_outlined, color: AppColors.of(context).inkSoft),
          const SizedBox(width: 8),
          Text('The picture is missing', style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _FullScreen extends StatelessWidget {
  const _FullScreen({required this.bytes, required this.label, this.credit = ''});
  final Uint8List bytes;
  final String label, credit;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Picture')),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Semantics(image: true, label: label, child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
              ),
            ),
            if (credit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(credit, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
              ),
          ]),
        ),
      );
}
