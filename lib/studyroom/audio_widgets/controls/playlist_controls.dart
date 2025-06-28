import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/theme_provider.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onBackgroundSoundPressed,
    required this.onAudioSourcePressed,
    super.key,
  });

  final ValueChanged<bool> onBackgroundSoundPressed;
  final ValueChanged<bool> onAudioSourcePressed;

  @override
  State<IconControls> createState() => IconControlsState();
}

class IconControlsState extends State<IconControls> {
  bool isBackgroundSoundEnabled = false;
  bool isAudioSourceEnabled = false;

  void closeAll() {
    setState(() {
      isBackgroundSoundEnabled = false;
      isAudioSourceEnabled = false;

      widget.onBackgroundSoundPressed(false);
      widget.onAudioSourcePressed(false);
    });
  }

  void _toggleControl(String control) {
    setState(() {
      if (control == 'background') {
        if (isBackgroundSoundEnabled) {
          isBackgroundSoundEnabled = false;
          widget.onBackgroundSoundPressed(false);
        } else {
          isBackgroundSoundEnabled = true;
          isAudioSourceEnabled = false;
          widget.onBackgroundSoundPressed(true);
          widget.onAudioSourcePressed(false);
        }
      } else if (control == 'audio') {
        if (isAudioSourceEnabled) {
          isAudioSourceEnabled = false;
          widget.onAudioSourcePressed(false);
        } else {
          isAudioSourceEnabled = true;
          isBackgroundSoundEnabled = false;
          widget.onAudioSourcePressed(true);
          widget.onBackgroundSoundPressed(false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return SizedBox(
      width: 200, // Adjusted width for both buttons.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Background Sound button.
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isBackgroundSoundEnabled
                  ? theme.lightEmphasisColor.withOpacity(0.6)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Background Sounds',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: () {
                final currentSource = Provider.of<AudioSourceSelectionProvider>(
                  context,
                  listen: false,
                ).currentSource;

                if (currentSource == AudioSourceType.spotify) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Background sounds are unavailable while using Spotify due to platform rules"),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.black87,
                    ),
                  );
                  return;
                } else {
                  _toggleControl('background');
                }
              },
              icon: Icon(Icons.headphones, color: theme.lightEmphasisColor),
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
                  ? theme.lightEmphasisColor.withOpacity(0.6)
                  : Colors.transparent,
            ),
            child: IconButton(
              tooltip: 'Audio Source',
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: () => _toggleControl('audio'),
              icon: Icon(Icons.audiotrack, color: theme.lightEmphasisColor),
            ),
          ),
        ],
      ),
    );
  }
}
