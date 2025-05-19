import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:url_launcher/url_launcher.dart'; // Required for launching URL

import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/shimmer_list_widget.dart';

class SpotifyTracksView extends StatelessWidget {
  final SpotifyPlaylistSimple playlist;
  final List<SpotifyTrackSimple>? tracks;
  final bool isLoading;
  final String? currentlyPlayingUri;
  final bool isSdkPlayerPaused;
  final VoidCallback onBack;
  final VoidCallback? onClosePanel;
  final Future<void> Function() onRefresh;
  final Function(String trackUri) onTrackTapPlay;
  final VoidCallback onToggleCurrentTrackPlayback;

  final _logger = getLogger('SpotifyTracksView');

  // Updated to Spotify brand color
  static const Color accentColor = Colors.deepOrange;
  static const Color spotifyBlack = Color(0xFF191414); // Spotify Black

  SpotifyTracksView({
    super.key,
    required this.playlist,
    required this.tracks,
    required this.isLoading,
    this.currentlyPlayingUri,
    required this.isSdkPlayerPaused,
    required this.onBack,
    this.onClosePanel,
    required this.onRefresh,
    required this.onTrackTapPlay,
    required this.onToggleCurrentTrackPlayback,
  });

  @override
  Widget build(BuildContext context) {
    _logger.v(
        "Building widget. Track count: ${tracks?.length}, Playing URI: $currentlyPlayingUri");
    bool hasTracks = tracks != null && tracks!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: spotifyBlack.withOpacity(0.7), size: 24),
              onPressed: () {
                HapticFeedback.lightImpact();
                onBack();
              },
              tooltip: "Back to Playlists",
            ),
          ),
          if (hasTracks) _buildPlaylistInfo(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: RefreshIndicator(
                color: accentColor,
                onRefresh: onRefresh,
                child: (tracks == null && isLoading)
                    ? ShimmerListWidget(isPlaylist: false)
                    : !hasTracks
                        ? _buildEmptyState(context)
                        : _buildTracksList(context),
              ),
            ),
          ),
          _buildSpotifyAttribution(), // Moved attribution to the bottom
        ],
      ),
    );
  }

  Widget _buildPlaylistInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: CachedNetworkImage(
              imageUrl: playlist.imageUrl ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note,
                    color: Colors.white70, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: spotifyBlack,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  "${playlist.totalTracks} tracks",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.play_circle_filled_rounded,
                      label: "Play All",
                      onTap: tracks != null && tracks!.isNotEmpty
                          ? () {
                              HapticFeedback.mediumImpact();
                              onTrackTapPlay(tracks!.first.uri);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_rounded,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    Text('No tracks in this playlist',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    Text(
                        'Add some tracks to this playlist in Spotify and pull down to refresh.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        )),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh Now'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildTracksList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: tracks!.length + 2, // +1 for header, +1 for footer
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header section with count and search (future feature)
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Row(
              children: [
                Text(
                  "${tracks!.length} Tracks",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        } else if (index == tracks!.length + 1) {
          // Footer with attribution reminder
          return _buildListFooter();
        }

        final trackIndex = index - 1;
        final track = tracks![trackIndex];
        bool isCurrentlyPlayingThisTrack = track.uri == currentlyPlayingUri;

        return _buildTrackListItem(
            context, track, trackIndex, isCurrentlyPlayingThisTrack);
      },
    );
  }

  Widget _buildTrackListItem(BuildContext context, SpotifyTrackSimple track,
      int index, bool isCurrentlyPlayingThisTrack) {
    Color tileColor = isCurrentlyPlayingThisTrack
        ? accentColor.withOpacity(0.08)
        : Colors.transparent;
    Color titleColor = isCurrentlyPlayingThisTrack
        ? accentColor
        : spotifyBlack; // Changed to spotifyBlack for non-playing
    FontWeight titleFontWeight =
        isCurrentlyPlayingThisTrack ? FontWeight.bold : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: () {
            _logger.i(
                "Track '${track.name}' tapped. Is playing this: $isCurrentlyPlayingThisTrack");
            HapticFeedback.lightImpact();
            if (isCurrentlyPlayingThisTrack) {
              onToggleCurrentTrackPlayback();
            } else {
              onTrackTapPlay(track.uri);
            }
          },
          borderRadius: BorderRadius.circular(12.0),
          hoverColor: Colors.grey.shade100.withOpacity(0.7),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  "${index + 1}",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCurrentlyPlayingThisTrack
                        ? accentColor
                        : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: CachedNetworkImage(
                          imageUrl: track.albumImageUrl ?? '',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.grey[200],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note,
                                color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        // Re-added Row for explicit badge
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Assuming SpotifyTrackSimple has an 'isExplicit' boolean field.

                          Expanded(
                            child: Text(track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: titleFontWeight,
                                    color: titleColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(track.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                isCurrentlyPlayingThisTrack
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSdkPlayerPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSdkPlayerPaused ? "Play" : "Pause",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(_formatDuration(track.durationMs),
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to format duration
  String _formatDuration(int milliseconds) {
    final int seconds = (milliseconds / 1000).floor() % 60;
    final int minutes = (milliseconds / 60000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSpotifyAttribution() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final Uri url = Uri.parse('https://www.spotify.com');
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              _logger.w("Could not launch ${url.toString()}");
            }
          },
          child: Image.asset(
            'assets/brand/spotify_logo_full_black.png', // Full logo (icon + wordmark)
            height:
                24, // Ensure height maintains aspect ratio for >= 70px width
            fit: BoxFit.contain,
            semanticLabel: 'Powered by Spotify. Links to Spotify.com',
          ),
        ),
      ),
    );
  }

  // Update footer to avoid redundancy
  Widget _buildListFooter() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final Uri url = Uri.parse('https://www.spotify.com');
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              _logger.w("Could not launch ${url.toString()}");
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(
              'Open in Spotify',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
