import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/theme_provider.dart';

class MusicControlButton extends StatelessWidget {
  const MusicControlButton({
    super.key,
    required this.splashLength,
    required this.iconSize,
    required this.icon,
    required this.onPressed,
    required this.iconColor,
  })  : assert(iconSize > 0),
        assert(splashLength > 0),
        assert(splashLength >= iconSize);

  final double splashLength;
  final double iconSize;
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: splashLength,
      width: splashLength,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        color: iconColor,
        icon: Icon(
          icon,
          size: iconSize,
        ),
        onPressed: () => onPressed(),
      ),
    );
  }
}

class Controls extends StatelessWidget {
  const Controls(
      {required this.onShuffle,
      required this.onPrevious,
      required this.onPlay,
      required this.onPause,
      required this.onNext,
      required this.onFavorite,
      required this.isPlaying,
      required this.isFavorite,
      required this.showFavorite,
      required this.showShuffle,
      super.key});

  final void Function() onShuffle;
  final void Function() onPrevious;
  final void Function() onPlay;
  final void Function() onPause;
  final void Function() onNext;
  final ValueChanged<bool> onFavorite;
  final bool isFavorite;
  final bool isPlaying;
  final bool showFavorite;
  final bool showShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    const double mainIconSize = 35.0;
    const double secondaryIconSize = 15.0;
    return SizedBox(
        height: 100,
        width: 300,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showFavorite)
              MusicControlButton(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                iconSize: secondaryIconSize,
                splashLength: secondaryIconSize + 10,
                onPressed: () {
                  onFavorite(!isFavorite);
                },
                iconColor: isFavorite
                    ? theme.favoriteIconColor
                    : theme.lightEmphasisColor,
              ),
            const SizedBox(width: 7.0),
            MusicControlButton(
              icon: Icons.skip_previous,
              iconSize: mainIconSize,
              splashLength: mainIconSize,
              onPressed: () => onPrevious(),
              iconColor: theme.lightEmphasisColor,
            ),
            const SizedBox(width: 3.0),
            MusicControlButton(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              iconSize: mainIconSize,
              splashLength: mainIconSize,
              onPressed: () {
                if (isPlaying) {
                  onPause();
                } else {
                  onPlay();
                }
              },
              iconColor: theme.lightEmphasisColor,
            ),
            const SizedBox(width: 3.0),
            MusicControlButton(
              icon: Icons.skip_next,
              iconSize: mainIconSize,
              splashLength: mainIconSize,
              onPressed: () => onNext(),
              iconColor: theme.lightEmphasisColor,
            ),
            const SizedBox(width: 7.0),
            if (showShuffle)
              MusicControlButton(
                icon: Icons.shuffle,
                iconSize: secondaryIconSize,
                splashLength: secondaryIconSize + 10,
                onPressed: () => onShuffle(),
                iconColor: theme.lightEmphasisColor,
              ),
          ],
        ));
  }
}
