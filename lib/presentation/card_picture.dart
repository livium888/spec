import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'theme/tokens.dart';

/// A picture on a card. Tap to see it full screen and zoom. The description (if any) is what a
/// screen reader announces.
class CardPicture extends ConsumerWidget {
  const CardPicture({super.key, required this.sha, this.alt = '', this.maxHeight = 260});
  final String sha, alt;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final label = alt.isEmpty ? 'Picture on the card' : alt;
    return ref.watch(mediaBytesProvider(sha)).when(
          loading: () => SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: c.accent))),
          error: (_, _) => _missing(context),
          data: (bytes) => bytes == null
              ? _missing(context)
              : Semantics(
                  image: true,
                  label: label,
                  button: true,
                  hint: 'Opens the picture full screen',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        fullscreenDialog: true, builder: (_) => _FullScreen(bytes: bytes, label: label))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Rd.card),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: Image.memory(bytes, fit: BoxFit.contain, cacheWidth: 1080, gaplessPlayback: true, excludeFromSemantics: true),
                      ),
                    ),
                  ),
                ),
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
  const _FullScreen({required this.bytes, required this.label});
  final Uint8List bytes;
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Picture')),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              maxScale: 6,
              child: Semantics(image: true, label: label, child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
        ),
      );
}
