import 'package:flutter/material.dart';

class IconControls extends StatefulWidget {
  const IconControls({
    required this.onInfoPressed,
    required this.onListPressed,
    required this.onSharePressed,
    super.key,
  });

  final ValueChanged<bool> onInfoPressed;
  final ValueChanged<bool> onListPressed;
  final ValueChanged<bool> onSharePressed;

  @override
  State<IconControls> createState() => _IconControlsState();
}

class _IconControlsState extends State<IconControls> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EnabledIconButton(
              icon: Icons.info,
              callback: widget.onInfoPressed,
            ),
            const SizedBox(width: 10),
            EnabledIconButton(
              icon: Icons.queue_music,
              callback: widget.onListPressed,
            ),
          ],
        ));
  }
}

class EnabledIconButton extends StatefulWidget {
  const EnabledIconButton({
    super.key,
    required this.callback,
    required this.icon,
  });

  final IconData icon;
  final ValueChanged<bool> callback;

  @override
  State<EnabledIconButton> createState() => _EnabledIconButtonState();
}

class _EnabledIconButtonState extends State<EnabledIconButton> {
  bool enabled = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: enabled
            ? const Color.fromRGBO(170, 170, 170, 0.7)
            : Colors.transparent,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        hoverColor: Colors.transparent,
        onPressed: () {
          setState(() {
            enabled = !enabled;
          });
          widget.callback(enabled);
        },
        icon: Icon(widget.icon),
      ),
    );
  }
}
