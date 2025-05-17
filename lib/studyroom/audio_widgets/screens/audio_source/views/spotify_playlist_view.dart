import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/shimmer_list_widget.dart';

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
              16.0, 16.0, 16.0, 12.0), // Consistent padding
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: kFlourishBlackish.withOpacity(0.9), size: 22),
                onPressed: onBack,
                tooltip: 'Back to Sources'),
            Expanded(
                child: Text("Your Playlists",
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kFlourishBlackish),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
            if (onClosePanel != null)
              IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: kFlourishBlackish.withOpacity(0.7), size: 24),
                  onPressed: onClosePanel,
                  tooltip: 'Close Panel')
            else
              const SizedBox(width: 48), // Keep for alignment
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0), // Main horizontal padding for the list area
            child: RefreshIndicator(
              color: kFlourishAdobe,
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
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              top: 8,
                              bottom: 24), // Padding for the list itself
                          itemCount: playlists!.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists![index];
                            return Card(
                              color: kFlourishAliceBlue,
                              elevation: 5,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadowColor: Colors.black.withOpacity(0.15),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  _logger
                                      .i("Playlist '${playlist.name}' tapped.");
                                  HapticFeedback.lightImpact();
                                  onPlaylistTap(playlist);
                                },
                                borderRadius: BorderRadius.circular(16),
                                hoverColor: Theme.of(context)
                                    .primaryColorLight
                                    .withOpacity(0.12),
                                splashColor: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.25),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          playlist.imageUrl ?? '',
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.music_note,
                                                color: Colors.white70,
                                                size: 36),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playlist.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: kFlourishBlackish,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${playlist.totalTracks} tracks',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 22,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ),
      ],
    );
  }
}
