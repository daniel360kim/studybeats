import 'package:flutter/material.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onInfoPressed,
    required this.onListPressed,
    required this.onEqualizerPressed,
    super.key,
  });

  final ValueChanged<bool> onInfoPressed;
  final ValueChanged<bool> onListPressed;
  final ValueChanged<bool> onEqualizerPressed;

  @override
  State<IconControls> createState() => _IconControlsState();
}

class _IconControlsState extends State<IconControls> {
  bool isInfoEnabled = false;
  bool isListEnabled = false;
  bool isEqualizerEnabled = false;

  void _handleInfoPressed() {
    setState(() {
      isInfoEnabled = !isInfoEnabled;
      if (isInfoEnabled) {
        isListEnabled = false;
        isEqualizerEnabled = false;

        widget.onListPressed(false);
        widget.onEqualizerPressed(false);
      }
    });
    widget.onInfoPressed(isInfoEnabled);
    if (!isInfoEnabled) {
      widget.onListPressed(false);
      widget.onEqualizerPressed(false);
    }
  }

  void _handleListPressed() {
    setState(() {
      isListEnabled = !isListEnabled;
      if (isListEnabled) {
        isInfoEnabled = false;
        isEqualizerEnabled = false;

        widget.onInfoPressed(false);
        widget.onEqualizerPressed(false);
      }
    });
    widget.onListPressed(isListEnabled);
    if (!isListEnabled) {
      widget.onInfoPressed(false);
      widget.onEqualizerPressed(false);
    }
  }

  void _handleEqualizerPressed() {
    setState(() {
      isEqualizerEnabled = !isEqualizerEnabled;
      if (isEqualizerEnabled) {
        isInfoEnabled = false;
        isListEnabled = false;

        widget.onInfoPressed(false);
        widget.onListPressed(false);
      }
    });
    widget.onEqualizerPressed(isEqualizerEnabled);
    if (!isEqualizerEnabled) {
      widget.onInfoPressed(false);
      widget.onListPressed(false);
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
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleEqualizerPressed,
              icon: const Icon(Icons.graphic_eq),
            ),
          ),
        ],
      ),
    );
  }
}
