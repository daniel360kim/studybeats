import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/shimmer_list_widget.dart';

class LofiTracksView extends StatelessWidget {
  final List<LofiSongMetadata>? tracks;
  final bool isLoading;
  final int? currentlyPlayingId;
  final bool isPlayerPaused;
  final VoidCallback onBack;
  final VoidCallback? onClosePanel;
  final Future<void> Function() onRefresh;
  final Function(int trackId) onTrackTapPlay;
  final VoidCallback onToggleCurrentTrackPlayback;
  final Playlist playlist;

  final _logger = getLogger('LofiTracksView');

  LofiTracksView({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.currentlyPlayingId,
    required this.isPlayerPaused,
    required this.onBack,
    this.onClosePanel,
    required this.onRefresh,
    required this.onTrackTapPlay,
    required this.onToggleCurrentTrackPlayback,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.primaryAppColor;
    bool hasTracks = tracks != null && tracks!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTracks) _buildPlaylistInfo(context, themeProvider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: RefreshIndicator(
                color: accentColor,
                onRefresh: onRefresh,
                child: (tracks == null && isLoading)
                    ? ShimmerListWidget(isPlaylist: false)
                    : !hasTracks
                        ? _buildEmptyState(context, themeProvider)
                        : _buildTracksList(context, themeProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistInfo(BuildContext context, ThemeProvider themeProvider) {
    final accentColor = themeProvider.primaryAppColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: themeProvider.isDarkMode
            ? []
            : [
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
            child: Container(
              width: 80,
              height: 80,
              color: themeProvider.dividerColor,
              child: (tracks != null && tracks!.isNotEmpty)
                  ? GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: tracks!.length >= 4 ? 4 : 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: tracks!.length >= 4 ? 2 : 1,
                      ),
                      itemBuilder: (context, i) {
                        return CachedNetworkImage(
                          imageUrl: tracks![i].artworkUrl100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: themeProvider.dividerColor),
                          errorWidget: (context, url, error) => Container(
                            color: themeProvider.dividerColor,
                            child: const Icon(Icons.music_note,
                                color: Colors.white70, size: 20),
                          ),
                        );
                      },
                    )
                  : const Icon(Icons.music_note,
                      color: Colors.white70, size: 40),
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
                    color: themeProvider.mainTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  "${playlist.numSongs} tracks",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: themeProvider.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionButton(
                      context,
                      themeProvider,
                      icon: Icons.play_circle_filled_rounded,
                      label: "Play All",
                      onTap: tracks != null && tracks!.isNotEmpty
                          ? () {
                              HapticFeedback.mediumImpact();
                              onTrackTapPlay(tracks!.first.id);
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
    BuildContext context,
    ThemeProvider themeProvider, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;
    final accentColor = themeProvider.primaryAppColor;

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

  Widget _buildEmptyState(BuildContext context, ThemeProvider themeProvider) {
    final accentColor = themeProvider.primaryAppColor;
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
                      size: 64, color: themeProvider.secondaryTextColor),
                  const SizedBox(height: 24),
                  Text('No tracks in this playlist',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.mainTextColor)),
                  const SizedBox(height: 12),
                  Text(
                    'Add some tracks to this playlist in Spotify and pull down to refresh.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTracksList(BuildContext context, ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: tracks!.length + 1,
      itemBuilder: (context, index) {
        if (index == tracks!.length) {
          return _buildSpotifyAttribution(themeProvider);
        }

        final track = tracks![index];
        bool isCurrentlyPlayingThisTrack = track.id == currentlyPlayingId;

        return _buildTrackListItem(
            context, track, index, isCurrentlyPlayingThisTrack, themeProvider);
      },
    );
  }

  Widget _buildTrackListItem(
      BuildContext context,
      LofiSongMetadata track,
      int index,
      bool isCurrentlyPlayingThisTrack,
      ThemeProvider themeProvider) {
    final accentColor = themeProvider.primaryAppColor;
    Color tileColor = isCurrentlyPlayingThisTrack
        ? accentColor.withOpacity(0.08)
        : Colors.transparent;
    Color titleColor =
        isCurrentlyPlayingThisTrack ? accentColor : themeProvider.mainTextColor;
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
                "Track '${track.trackName}' tapped. Is playing this: $isCurrentlyPlayingThisTrack");
            HapticFeedback.lightImpact();
            if (isCurrentlyPlayingThisTrack) {
              onToggleCurrentTrackPlayback();
            } else {
              onTrackTapPlay(track.id);
            }
          },
          borderRadius: BorderRadius.circular(12.0),
          hoverColor: themeProvider.dividerColor.withOpacity(0.5),
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
                        : themeProvider.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: themeProvider.isDarkMode
                            ? []
                            : [
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
                          imageUrl: track.artworkUrl100,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                              width: 52,
                              height: 52,
                              color: themeProvider.dividerColor),
                          errorWidget: (context, url, error) => Container(
                            width: 52,
                            height: 52,
                            color: themeProvider.dividerColor,
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
                      Text(track.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: titleFontWeight,
                              color: titleColor)),
                      const SizedBox(height: 4),
                      Text(track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: themeProvider.secondaryTextColor)),
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
                              isPlayerPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPlayerPaused ? "Play" : "Pause",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(_formatDuration((track.trackTime * 1000).toInt()),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: themeProvider.secondaryTextColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final int seconds = (milliseconds / 1000).floor() % 60;
    final int minutes = (milliseconds / 60000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSpotifyAttribution(ThemeProvider themeProvider) {
    // Use a different asset for dark mode
    final logoAssetPath = themeProvider.isDarkMode
        ? 'assets/brand/spotify_logo_full_white.png'
        : 'assets/brand/spotify_logo_full_black.png';

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Center(
          child: SizedBox(),
        ));
  }
}
