import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart'; // Assuming kFlourishBlackish is here
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';

class SourceCardWidget extends StatelessWidget {
  final String title;
  final IconData? iconData;
  final Widget? iconWidget;
  final Widget? subtitleWidget;
  final AudioSourceType sourceType;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isSpotifyAuthenticated; // Kept for potential direct use if needed
  final Widget? trailing;
  final _logger = getLogger('SourceCardWidget');

  SourceCardWidget({
    // Made constructor const
    super.key,
    required this.title,
    this.iconData,
    this.iconWidget,
    this.subtitleWidget,
    required this.sourceType,
    required this.isSelected,
    required this.onTap,
    required this.isSpotifyAuthenticated,
    this.trailing,
  }) {
    _logger.d("Created for '$title', selected: $isSelected");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget for '$title'");
    final Gradient cardGradient = sourceType == AudioSourceType.spotify
        ? const LinearGradient(
            // Ensured this is const
            colors: [
              Colors.white,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Theme.of(context)
                  .primaryColor
                  .withOpacity(isSelected ? 0.25 : 0.15),
              Colors.white.withOpacity(isSelected ? 0.95 : 0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    Color iconColor = isSelected
        ? (sourceType == AudioSourceType.spotify
            ? Colors
                .white // This is for the default Icon(iconData), Spotify uses iconWidget
            : Theme.of(context).primaryColorDark)
        : Colors.grey.shade700;
    Color titleColor = kFlourishBlackish;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isSelected ? 1.0 : 0.9, // More subtle opacity change
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut, // Smoother curve
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.0), // Slightly larger radius
          gradient: cardGradient,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: sourceType == AudioSourceType.spotify
                        ? const Color(0xFF1DB954).withOpacity(0.3)
                        : Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
          border: Border.all(
            color: isSelected
                ? (sourceType == AudioSourceType.spotify
                    ? const Color(0xFF1DB954).withOpacity(0.8)
                    : Theme.of(context).primaryColor.withOpacity(0.8))
                : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _logger.i("Card '$title' tapped.");
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(14.0),
            splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
            hoverColor: Colors.transparent,
            highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 20.0), // Increased padding
              child: Row(
                children: [
                  if (iconWidget != null)
                    iconWidget!
                  else if (iconData != null)
                    Icon(iconData,
                        size: 34, color: iconColor), // Slightly larger icon
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 19, // Slightly larger title
                            fontWeight: FontWeight.bold, // Bolder title
                            color: titleColor,
                          ),
                        ),
                        if (subtitleWidget != null) ...[
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            // Animate subtitle changes
                            duration: const Duration(milliseconds: 200),
                            child: subtitleWidget,
                          )
                        ]
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    AnimatedSwitcher(
                      // Animate trailing widget changes
                      duration: const Duration(milliseconds: 200),
                      child: trailing,
                    )
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
