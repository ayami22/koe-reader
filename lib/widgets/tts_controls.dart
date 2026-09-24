import 'package:flutter/material.dart';

class TtsControls extends StatelessWidget {
  final bool isPlaying;
  final bool isConnected;
  final bool isSynthesizing;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const TtsControls({
    super.key,
    required this.isPlaying,
    required this.isConnected,
    required this.isSynthesizing,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(240),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isConnected)
            Expanded(
              child: Text(
                'TTS未接続 — 設定からサーバーを接続してください',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 32,
              onPressed: onPrevious,
            ),
            const SizedBox(width: 16),
            _PlayButton(
              isPlaying: isPlaying,
              isSynthesizing: isSynthesizing,
              onPressed: onPlayPause,
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 32,
              onPressed: onNext,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isSynthesizing;
  final VoidCallback onPressed;

  const _PlayButton({
    required this.isPlaying,
    required this.isSynthesizing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isSynthesizing) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primaryContainer,
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
      ),
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 28,
      ),
    );
  }
}
