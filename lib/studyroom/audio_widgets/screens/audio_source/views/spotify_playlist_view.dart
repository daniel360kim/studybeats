import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:url_launcher/url_launcher.dart'; // Required for launching URL

import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/shimmer_list_widget.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/views/spotify_tracks_view.dart'; // For spotifyGreen and spotifyBlack
import 'package:cached_network_image/cached_network_image.dart';

class SpotifyPlaylistView extends StatelessWidget {
  final List<SpotifyPlaylistSimple>? playlists;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback? onClosePanel;
  final Future<void> Function() onRefresh;
  final Function(SpotifyPlaylistSimple) onPlaylistTap;
  final _logger = getLogger('SpotifyPlaylistView');

  SpotifyPlaylistView({
    super.key,
    required this.playlists,
    required this.isLoading,
    required this.onBack,
    this.onClosePanel,
    required this.onRefresh,
    required this.onPlaylistTap,
  }) {
    _logger.d(
        "Created. isLoading: $isLoading, playlist count: ${playlists?.length}");
  }

  @override
  Widget build(BuildContext context) {
    _logger.t("Building widget. Playlist count: ${playlists?.length}");
    bool hasPlaylists = playlists != null && playlists!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              16.0, 16.0, 16.0, 12.0), // Restored original padding
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: kFlourishBlackish.withOpacity(0.9), size: 22),
                onPressed: onBack,
                tooltip: 'Back to Sources',
              ),
              Expanded(
                child: Text(
                  "Your Playlists",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: SpotifyTracksView.spotifyBlack,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClosePanel != null)
                IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: kFlourishBlackish.withOpacity(0.7), size: 24),
                    onPressed: onClosePanel,
                    tooltip: 'Close Panel')
              else
                const SizedBox(width: 48), // Keep for alignment
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0), // Main horizontal padding for the list area
            child: RefreshIndicator(
              color: SpotifyTracksView.accentColor, // Changed to spotifyGreen
              backgroundColor: Colors.white,
              onRefresh: onRefresh,
              child: (playlists == null && isLoading)
                  ? ShimmerListWidget(isPlaylist: true)
                  : !hasPlaylists
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // Always allow pull-to-refresh
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight *
                                      0.8), // Ensure content can fill viewport for centering
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.library_music_outlined,
                                              size: 60,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 20),
                                          Text('No Playlists Found',
                                              style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700])),
                                          const SizedBox(height: 10),
                                          Text(
                                              'Pull down to refresh, or create some awesome playlists on Spotify!',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  height: 1.5)),
                                        ],
                                      ))),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                              top: 8,
                              bottom: 24), // Padding for the list itself
                          itemCount: playlists!.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Divider(
                              color: Colors.grey.withOpacity(0.13),
                              thickness: 1,
                              height: 18,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final playlist = playlists![index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: InkWell(
                                onTap: () {
                                  _logger
                                      .i("Playlist '${playlist.name}' tapped.");
                                  HapticFeedback.lightImpact();
                                  onPlaylistTap(playlist);
                                },
                                borderRadius: BorderRadius.circular(12),
                                splashColor: Colors.black.withOpacity(0.05),
                                highlightColor: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4.0),
                                          child: CachedNetworkImage(
                                            imageUrl: playlist.imageUrl ?? '',
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                  Icons.music_note,
                                                  color: Colors.white70,
                                                  size: 30),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                playlist.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: SpotifyTracksView
                                                      .spotifyBlack,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${playlist.totalTracks} tracks',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 20,
                                            color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ),
        _buildSpotifyAttribution(), // Moved attribution to the bottom
      ],
    );
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
}
