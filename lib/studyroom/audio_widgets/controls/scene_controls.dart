import 'package:flutter/material.dart';

class SceneControls extends StatefulWidget {
  const SceneControls({
    required this.onScreneSelectPressed,
    required this.onChatPressed,
    required this.onTimerPressed,
    super.key,
  });

  final ValueChanged<bool> onScreneSelectPressed;
  final ValueChanged<bool> onChatPressed;
  final ValueChanged<bool> onTimerPressed;

  @override
  SceneControlsState createState() => SceneControlsState();

  void handleTimerPressed(GlobalKey<SceneControlsState> key) {
    key.currentState?._handleTimerPressed();
  }
}

class SceneControlsState extends State<SceneControls> {
  bool isSceneSelectEnable = false;
  bool isChatEnabled = false;
  bool isTimerEnabled = false;

  void _handleInfoPressed() {
    setState(() {
      isSceneSelectEnable = !isSceneSelectEnable;
      if (isSceneSelectEnable) {
        isChatEnabled = false;
        isTimerEnabled = false;

        widget.onChatPressed(false);
        widget.onTimerPressed(false);
      }
    });
    widget.onScreneSelectPressed(isSceneSelectEnable);
    if (!isSceneSelectEnable) {
      widget.onChatPressed(false);
      widget.onTimerPressed(false);
    }
  }

  void _handleChatPressed() {
    setState(() {
      isChatEnabled = !isChatEnabled;
      if (isChatEnabled) {
        isSceneSelectEnable = false;
        isTimerEnabled = false;

        widget.onScreneSelectPressed(false);
        widget.onTimerPressed(false);
      }
    });
    widget.onChatPressed(isChatEnabled);
    if (!isChatEnabled) {
      widget.onScreneSelectPressed(false);
      widget.onTimerPressed(false);
    }
  }

  void _handleTimerPressed() {
    setState(() {
      isTimerEnabled = !isTimerEnabled;
      if (isTimerEnabled) {
        isSceneSelectEnable = false;
        isChatEnabled = false;

        widget.onScreneSelectPressed(false);
        widget.onChatPressed(false);
      }
    });
    widget.onTimerPressed(isTimerEnabled);
    if (!isTimerEnabled) {
      widget.onScreneSelectPressed(false);
      widget.onChatPressed(false);
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
              color: isSceneSelectEnable
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleInfoPressed,
              icon: const Icon(Icons.splitscreen_sharp),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isChatEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleChatPressed,
              icon: const Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isTimerEnabled
                  ? const Color.fromRGBO(170, 170, 170, 0.7)
                  : Colors.transparent,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              hoverColor: Colors.transparent,
              onPressed: _handleTimerPressed,
              icon: const Icon(Icons.timer_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
