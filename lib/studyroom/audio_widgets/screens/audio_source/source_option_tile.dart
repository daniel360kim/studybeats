import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/audio_source_type.dart'; // Assuming kFlourishBlackish is here

/// A reusable tile widget for selecting an audio source, now with subtitle support.
class SourceOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle; // New optional subtitle
  final TextStyle? subtitleStyle; // Optional style for the subtitle
  final IconData? iconData;
  final Widget? customIcon;
  final AudioSourceType sourceType;
  final bool isSelected;
  final bool requiresAuth; // Indicate if this option needs authentication
  final VoidCallback onTap;

  const SourceOptionTile({
    super.key,
    required this.title,
    this.subtitle, // Added subtitle
    this.subtitleStyle, // Added subtitleStyle
    this.iconData,
    this.customIcon,
    required this.sourceType,
    required this.isSelected,
    required this.onTap,
    this.requiresAuth = false,
  });

  @override
  Widget build(BuildContext context) {
    // Default subtitle style if none provided
    final defaultSubtitleStyle = GoogleFonts.inter(
      fontSize: 12,
      color: isSelected ? Colors.blueGrey[700] : Colors.grey[600],
      fontWeight: FontWeight.normal,
    );

    return Material(
      color:
          isSelected ? Colors.blueGrey.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.blueGrey.withOpacity(0.2),
        highlightColor: Colors.blueGrey.withOpacity(0.1),
        child: Padding(
          // Adjust vertical padding slightly if subtitle is present
          padding: EdgeInsets.symmetric(
              vertical: subtitle != null ? 10.0 : 14.0, horizontal: 16.0),
          child: Row(
            children: [
              // Leading Icon (Custom or Standard)
              if (customIcon != null)
                Padding(
                  padding: const EdgeInsets.only(
                      right: 16.0), // Add padding to separate icon
                  child: customIcon,
                )
              else if (iconData != null)
                Padding(
                  padding: const EdgeInsets.only(
                      right: 16.0), // Add padding to separate icon
                  child: Icon(
                    iconData,
                    size: 26,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                  ),
                )
              else // Add SizedBox if no icon to maintain alignment
                const SizedBox(width: 26 + 16.0), // Icon size + padding

              // Title and Subtitle Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center vertically
                  children: [
                    // Title Text
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? kFlourishBlackish // Use your defined color
                            : kFlourishBlackish.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Subtitle Text (if provided)
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 2.0), // Space between title and subtitle
                        child: Text(
                          subtitle!,
                          style: subtitleStyle ?? defaultSubtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              // Trailing Icons (Checkmark or Login)
              if (isSelected && !requiresAuth)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                )
              // Removed the login icon from here as status is shown in subtitle/icon color now
              // else if (sourceType == AudioSourceType.spotify && requiresAuth && !isSelected)
              //   Padding(
              //     padding: const EdgeInsets.only(left: 8.0),
              //     child: Icon(Icons.login,
              //         color: Colors.orangeAccent[700], size: 20, semanticLabel: 'Login required'),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
