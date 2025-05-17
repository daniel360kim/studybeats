import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
// Only for type hint if needed, parent passes bool
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';

import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/source_card_widget.dart';

class SourceSelectionView extends StatelessWidget {
  final AudioSourceType selectedSource;
  final bool isSpotifyAuthenticated;
  final bool isSpotifyPlayerConnecting;
  final bool isSpotifyPlayerConnected;
  final bool isSpotifyPlayerDisconnected;
  final bool isSpotifyPlayerError;
  final String? spotifyPlayerErrorMessage;

  final VoidCallback? onClosePanel;
  final Function(AudioSourceType) onSelectSource;
  final VoidCallback onSpotifyLoginTap;
  final VoidCallback onSpotifyLogout;
  final VoidCallback onViewPlaylistsTap;
  final VoidCallback onRetryPlayerConnection;

  final SpotifyTrackSimple? currentPlayingTrack;
  final bool isSdkPlayerPaused;
  final VoidCallback onToggleSdkPlayerPlayback;

  final _logger = getLogger('SourceSelectionView');

  SourceSelectionView({
    super.key,
    required this.selectedSource,
    required this.isSpotifyAuthenticated,
    required this.isSpotifyPlayerConnecting,
    required this.isSpotifyPlayerConnected,
    required this.isSpotifyPlayerDisconnected,
    required this.isSpotifyPlayerError,
    this.spotifyPlayerErrorMessage,
    this.onClosePanel,
    required this.onSelectSource,
    required this.onSpotifyLoginTap,
    required this.onSpotifyLogout,
    required this.onViewPlaylistsTap,
    required this.onRetryPlayerConnection,
    this.currentPlayingTrack,
    required this.isSdkPlayerPaused,
    required this.onToggleSdkPlayerPlayback,
  }) {
    _logger.d(
        "Created. Selected: $selectedSource, Auth: $isSpotifyAuthenticated, PlayerConnected: $isSpotifyPlayerConnected");
  }

  Widget _buildPlayerStatusIndicator(BuildContext context) {
    if (isSpotifyPlayerError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.redAccent.shade100, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(spotifyPlayerErrorMessage ?? "Player Error",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.redAccent.shade100,
                      fontWeight: FontWeight.w500))),
        ],
      );
    }
    return const SizedBox
        .shrink(); // No status to show if not authenticated or none of the above
  }

  @override
  Widget build(BuildContext context) {
    _logger.v(
        "Building widget. PlayerConnecting: $isSpotifyPlayerConnecting, PlayerConnected: $isSpotifyPlayerConnected");

    Widget spotifyIconWidget = CircleAvatar(
      radius: 18,
      backgroundColor:
          isSpotifyAuthenticated ? Colors.green.shade600 : Colors.grey.shade400,
      child: Image.asset('assets/brand/spotify.png',
          width: 20, height: 20, color: Colors.white),
    );

    Widget? spotifyMainActionWidget;
    Widget? spotifyTrailingWidget;

    if (!isSpotifyAuthenticated) {
      spotifyMainActionWidget = Text(
        "Tap to connect Spotify",
        style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500),
      );
    } else {
      // If authenticated, the main action is to view playlists
      spotifyMainActionWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "View Playlists",
            style: GoogleFonts.inter(
              fontSize: 14, // Slightly larger for the main action
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          _buildPlayerStatusIndicator(
              context), // Display status below "View Playlists"
        ],
      );

      // Trailing widget for logout or retry
      if (isSpotifyPlayerConnected) {
        spotifyTrailingWidget = IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: Colors.redAccent, size: 22),
          onPressed: onSpotifyLogout,
          tooltip: "Logout Spotify",
        );
      } else if (isSpotifyPlayerDisconnected || isSpotifyPlayerError) {
        spotifyTrailingWidget = IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: selectedSource == AudioSourceType.spotify
                  ? Colors.white70
                  : Colors.blueGrey.shade700,
              size: 22),
          tooltip: isSpotifyPlayerError
              ? (spotifyPlayerErrorMessage ?? "Player Error. Retry?")
              : "Player Disconnected. Retry?",
          onPressed: onRetryPlayerConnection,
        );
      } else if (isSpotifyPlayerConnecting) {
        spotifyTrailingWidget = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Choose your audio source',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kFlourishBlackish)),
            if (onClosePanel != null)
              IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: kFlourishBlackish.withOpacity(0.7), size: 24),
                  onPressed: onClosePanel,
                  tooltip: 'Close Panel'),
          ]),
          const SizedBox(height: 28),
          SourceCardWidget(
            title: 'Lofi Radio',
            iconData: Icons.radio_rounded,
            sourceType: AudioSourceType.lofi,
            isSelected: selectedSource == AudioSourceType.lofi,
            onTap: () => onSelectSource(AudioSourceType.lofi),
            isSpotifyAuthenticated: isSpotifyAuthenticated,
          ),
          const SizedBox(height: 18),
          SourceCardWidget(
            title: 'Spotify',

            iconWidget: spotifyIconWidget,
            subtitleWidget:
                spotifyMainActionWidget, // This now includes "View Playlists" and status
            sourceType: AudioSourceType.spotify,
            isSelected: selectedSource == AudioSourceType.spotify,
            onTap: () {
              HapticFeedback.lightImpact();
              onSelectSource(AudioSourceType.spotify); // Select first
              if (!isSpotifyAuthenticated) {
                onSpotifyLoginTap(); // Trigger login dialog
              } else {
                // If authenticated, tapping the card should primarily lead to playlists
                // or retry connection if there's an issue.
                if (isSpotifyPlayerConnected ||
                    isSpotifyPlayerConnecting ||
                    currentPlayingTrack != null /* or userPlaylists exist */) {
                  onViewPlaylistsTap();
                } else if (isSpotifyPlayerError ||
                    isSpotifyPlayerDisconnected) {
                  onRetryPlayerConnection();
                } else {
                  // Initial state after auth, or if player is 'none'
                  onViewPlaylistsTap(); // Default to viewing playlists, which might also trigger player init
                }
              }
            },
            isSpotifyAuthenticated: isSpotifyAuthenticated,
            trailing: spotifyTrailingWidget,
          ),
        ],
      ),
    );
  }
}
