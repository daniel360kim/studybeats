import 'package:flutter/material.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onInfoPressed,
    required this.onListPressed,
    required this.onEqualizerPressed,
    required this.onBackgroundSoundPressed,
    super.key,
  });

  final ValueChanged<bool> onInfoPressed;
  final ValueChanged<bool> onListPressed;
  final ValueChanged<bool> onEqualizerPressed;
  final ValueChanged<bool> onBackgroundSoundPressed;

  @override
  State<IconControls> createState() => _IconControlsState();
}

class _IconControlsState extends State<IconControls> {
  bool isInfoEnabled = false;
  bool isListEnabled = false;
  bool isEqualizerEnabled = false;
  bool isBackgroundSoundEnabled = false;

  void _handleInfoPressed() {
    setState(() {
      isInfoEnabled = !isInfoEnabled;
      if (isInfoEnabled) {
        isListEnabled = false;
        isEqualizerEnabled = false;
        isBackgroundSoundEnabled = false;

        widget.onListPressed(false);
        widget.onEqualizerPressed(false);
        widget.onBackgroundSoundPressed(false);
      }
    });
    widget.onInfoPressed(isInfoEnabled);
    if (!isInfoEnabled) {
      widget.onListPressed(false);
      widget.onEqualizerPressed(false);
      widget.onBackgroundSoundPressed(false);
    }
  }

  void _handleListPressed() {
    setState(() {
      isListEnabled = !isListEnabled;
      if (isListEnabled) {
        isInfoEnabled = false;
        isEqualizerEnabled = false;
        isBackgroundSoundEnabled = false;

        widget.onInfoPressed(false);
        widget.onEqualizerPressed(false);
        widget.onBackgroundSoundPressed(false);
      }
    });
    widget.onListPressed(isListEnabled);
    if (!isListEnabled) {
      widget.onInfoPressed(false);
      widget.onEqualizerPressed(false);
      widget.onBackgroundSoundPressed(false);
    }
  }

  void _handleEqualizerPressed() {
    setState(() {
      isEqualizerEnabled = !isEqualizerEnabled;
      if (isEqualizerEnabled) {
        isInfoEnabled = false;
        isListEnabled = false;
        isBackgroundSoundEnabled = false;

        widget.onInfoPressed(false);
        widget.onListPressed(false);
        widget.onBackgroundSoundPressed(false);
      }
    });
    widget.onEqualizerPressed(isEqualizerEnabled);
    if (!isEqualizerEnabled) {
      widget.onInfoPressed(false);
      widget.onListPressed(false);
      widget.onBackgroundSoundPressed(false);
    }
  }

  void _handleHeadponesPressed() {
    setState(() {
      isBackgroundSoundEnabled = !isBackgroundSoundEnabled;
      if (isBackgroundSoundEnabled) {
        isInfoEnabled = false;
        isListEnabled = false;
        isEqualizerEnabled = false;

        widget.onInfoPressed(false);
        widget.onListPressed(false);
        widget.onEqualizerPressed(false);
      }
    });
    widget.onBackgroundSoundPressed(isBackgroundSoundEnabled);
    if (!isBackgroundSoundEnabled) {
      widget.onInfoPressed(false);
      widget.onListPressed(false);
      widget.onEqualizerPressed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, // Adjusted width to accommodate the third button
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isInfoEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Song Info',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleInfoPressed,
              icon: const Icon(Icons.info),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isListEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Queue',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleListPressed,
              icon: const Icon(Icons.queue_music),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isEqualizerEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Waveforms',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleEqualizerPressed,
              icon: const Icon(Icons.graphic_eq),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isBackgroundSoundEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Background Sounds',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleHeadponesPressed,
              icon: const Icon(Icons.headphones),
            ),
          ),
        ],
      ),
    );
  }
}
