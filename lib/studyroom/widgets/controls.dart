import 'package:flutter/material.dart';

class MusicControlButton extends StatelessWidget {
  const MusicControlButton({
    super.key,
    required this.splashLength,
    required this.iconSize,
    required this.icon,
    required this.onPressed,
  })  : assert(iconSize > 0),
        assert(splashLength > 0),
        assert(splashLength >= iconSize);

  final double splashLength;
  final double iconSize;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: splashLength,
      width: splashLength,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: iconSize,
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
      super.key});

  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onNext;
  final VoidCallback onFavorite;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    const double mainIconSize = 35.0;
    const double secondaryIconSize = 15.0;
    return SizedBox(
        height: 100,
        width: 300,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MusicControlButton(
              icon: Icons.favorite,
              iconSize: secondaryIconSize,
              splashLength: secondaryIconSize + 10,
              onPressed: () {},
            ),
            const SizedBox(width: 7.0),
            MusicControlButton(
              icon: Icons.skip_previous,
              iconSize: mainIconSize,
              splashLength: mainIconSize,
              onPressed: () => onPrevious(),
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
            ),
            const SizedBox(width: 3.0),
            MusicControlButton(
              icon: Icons.skip_next,
              iconSize: mainIconSize,
              splashLength: mainIconSize,
              onPressed: () => onNext(),
            ),
            const SizedBox(width: 7.0),
            MusicControlButton(
              icon: Icons.shuffle,
              iconSize: secondaryIconSize,
              splashLength: secondaryIconSize + 10,
              onPressed: () => onShuffle(),
            ),
          ],
        ));
  }
}
