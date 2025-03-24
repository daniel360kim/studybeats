import 'package:flutter/material.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onListPressed,
    required this.onEqualizerPressed,
    required this.onBackgroundSoundPressed,
    super.key,
  });

  final ValueChanged<bool> onListPressed;
  final ValueChanged<bool> onEqualizerPressed;
  final ValueChanged<bool> onBackgroundSoundPressed;

  @override
  State<IconControls> createState() => IconControlsState();
}

class IconControlsState extends State<IconControls> {
  bool isEqualizerEnabled = false;
  bool isBackgroundSoundEnabled = false;

  void closeAll() {
    setState(() {
      isEqualizerEnabled = false;
      isBackgroundSoundEnabled = false;
      widget.onEqualizerPressed(false);
      widget.onBackgroundSoundPressed(false);
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
          widget.onEqualizerPressed(true);
          widget.onBackgroundSoundPressed(false);
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
        ],
      ),
    );
  }
}
