import 'package:flutter/material.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onListPressed,
    required this.onEqualizerPressed,
    required this.onBackgroundSoundPressed,
    required this.onAudioSourcePressed,
    super.key,
  });

  final ValueChanged<bool> onListPressed;
  final ValueChanged<bool> onEqualizerPressed;
  final ValueChanged<bool> onBackgroundSoundPressed;
  final ValueChanged<bool> onAudioSourcePressed;

  @override
  State<IconControls> createState() => IconControlsState();
}

class IconControlsState extends State<IconControls> {
  bool isEqualizerEnabled = false;
  bool isBackgroundSoundEnabled = false;
  bool isAudioSourceEnabled = false;

  void closeAll() {
    setState(() {
      isEqualizerEnabled = false;
      isBackgroundSoundEnabled = false;
      isAudioSourceEnabled = false;

      widget.onEqualizerPressed(false);
      widget.onBackgroundSoundPressed(false);
      widget.onAudioSourcePressed(false);
    });
  }

  void _toggleControl(String control) {
    setState(() {
      if (control == 'equalizer') {
        if (isEqualizerEnabled) {
          // Already open: close it.
          isEqualizerEnabled = false;
          widget.onEqualizerPressed(false);
        } else {
          // Open equalizer and ensure background is closed.
          isEqualizerEnabled = true;
          isBackgroundSoundEnabled = false;
          isAudioSourceEnabled = false;
          widget.onEqualizerPressed(true);
          widget.onBackgroundSoundPressed(false);
          widget.onAudioSourcePressed(false);
        }
      } else if (control == 'background') {
        if (isBackgroundSoundEnabled) {
          isBackgroundSoundEnabled = false;
          widget.onBackgroundSoundPressed(false);
        } else {
          isBackgroundSoundEnabled = true;
          isEqualizerEnabled = false;
          widget.onBackgroundSoundPressed(true);
          widget.onEqualizerPressed(false);
          widget.onAudioSourcePressed(false);
        }
      } else if (control == 'audio') {
        if (isAudioSourceEnabled) {
          isAudioSourceEnabled = false;
          widget.onAudioSourcePressed(false);
        } else {
          isAudioSourceEnabled = true;
          isEqualizerEnabled = false;
          isBackgroundSoundEnabled = false;
          widget.onAudioSourcePressed(true);
          widget.onEqualizerPressed(false);
          widget.onBackgroundSoundPressed(false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, // Adjusted width for both buttons.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          /*
          // Equalizer button.
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
              onPressed: () => _toggleControl('equalizer'),
              icon: const Icon(Icons.graphic_eq),
            ),
          ),
          */
          const SizedBox(width: 10),
          // Background Sound button.
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
              onPressed: () => _toggleControl('background'),
              icon: const Icon(Icons.headphones),
            ),
          ),
          const SizedBox(width: 10),
          // Audio Source button.
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isAudioSourceEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Audio Source',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: () => _toggleControl('audio'),
              icon: const Icon(Icons.audiotrack),
            ),
          ),
        ],
      ),
    );
  }
}
