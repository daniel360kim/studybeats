import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/theme_provider.dart';

class DateTimeWidget extends StatelessWidget {
  DateTimeWidget({super.key});
  // Remember whether the panel was open at tap-down on DateTimeWidget
  bool _panelWasOpenOnTap = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Provider.of<ThemeProvider>(context);
    final timeString = DateFormat('h:mm a').format(now);
    final dateString = DateFormat('EEE, MMM d').format(now);

    // Watch side‑panel open state to flip icon.
    final isOpen = context.watch<SidePanelController>().isOpen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Toggle side panel',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.grey.withOpacity(0.2),
            highlightColor: Colors.grey.withOpacity(0.1),
            onTapDown: (_) {
              _panelWasOpenOnTap =
                  context.read<SidePanelController>().isOpen; // remember state
            },
            onTap: () {
              final sidePanelController = context.read<SidePanelController>();

              if (_panelWasOpenOnTap) {
                // It was open when the pointer went down (TapRegion already closed it)
                // so don't reopen; just ensure it's closed.
                sidePanelController.close();
              } else {
                // It was closed, so open it now.
                sidePanelController.open();
              }
            }, // no‑op just to trigger splash; outer GestureDetector toggles panel
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.songInfoBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.lightEmphasisColor.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateString,
                        style: TextStyle(
                          color: theme.lightEmphasisColor,
                          fontSize: 11.5,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Icon(
                      isOpen ? Icons.chevron_left : Icons.chevron_right,
                      key: ValueKey(isOpen),
                      size: 20,
                      color: theme.lightEmphasisColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
