import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/widgets/image_placeholder_widget.dart';
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

  SpotifyTracksView({ // Made constructor const
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
  }) {
     _logger.d("Created for playlist: ${playlist.name}, isLoading: $isLoading, track count: ${tracks?.length}");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget. Track count: ${tracks?.length}, Playing URI: $currentlyPlayingUri");
    bool hasTracks = tracks != null && tracks!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0), // Adjusted bottom padding
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: kFlourishBlackish.withOpacity(0.8), size: 22),
                onPressed: onBack,
                tooltip: 'Back to Playlists'),
            Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(playlist.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kFlourishBlackish), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    if (playlist.totalTracks > 0) ... [
                       const SizedBox(height: 2),
                       Text("${playlist.totalTracks} tracks", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ]
                  ],
                )
            ),
            if (onClosePanel != null)
              IconButton(
                  icon: Icon(Icons.close_rounded, color: kFlourishBlackish.withOpacity(0.7), size: 24),
                  onPressed: onClosePanel,
                  tooltip: 'Close Panel')
            else
              const SizedBox(width: 48),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced horizontal padding for list
            child: RefreshIndicator(
              color: kFlourishAdobe,
              onRefresh: onRefresh,
              child: (tracks == null && isLoading)
                  ? ShimmerListWidget(isPlaylist: false) // Use dedicated shimmer
                  : !hasTracks
                      ? LayoutBuilder(
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
                                          Icon(Icons.music_off_rounded, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 16),
                                          Text('No tracks in this playlist', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                                          const SizedBox(height: 8),
                                          Text('Pull down to refresh.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
                                        ],
                                      ))),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0), // Padding for items
                          itemCount: tracks!.length,
                          separatorBuilder: (context, index) => Divider(height: 1, thickness: 0.4, color: Colors.grey.shade200, indent: 68, endIndent: 16), // Indented separator
                          itemBuilder: (context, index) {
                            final track = tracks![index];
                            bool isCurrentlyPlayingThisTrack = track.uri == currentlyPlayingUri;
                            Color tileColor = isCurrentlyPlayingThisTrack ? kFlourishAdobe.withOpacity(0.08) : Colors.transparent;
                            Color titleColor = isCurrentlyPlayingThisTrack ? kFlourishAdobe : kFlourishBlackish;
                            FontWeight titleFontWeight = isCurrentlyPlayingThisTrack ? FontWeight.bold : FontWeight.w500;

                            return Material( // Wrap with Material for InkWell splash to be visible on transparent tileColor
                              color: tileColor,
                              borderRadius: BorderRadius.circular(8.0),
                              child: InkWell(
                                onTap: () {
                                  _logger.i("Track '${track.name}' tapped. Is playing this: $isCurrentlyPlayingThisTrack");
                                  HapticFeedback.lightImpact();
                                  if (isCurrentlyPlayingThisTrack) {
                                    onToggleCurrentTrackPlayback();
                                  } else {
                                    onTrackTapPlay(track.uri);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8.0),
                                hoverColor: Colors.grey.shade100.withOpacity(0.7),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0), // Consistent padding
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ImagePlaceholderWidget(imageUrl: track.albumImageUrl, size: 48, borderRadius: 6.0),
                                          if(isCurrentlyPlayingThisTrack && !isSdkPlayerPaused)
                                            Container(
                                              width: 48, height: 48,
                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(6.0)),
                                              child: Icon(Icons.bar_chart_rounded, color: Colors.white.withOpacity(0.9), size: 28),
                                            )
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: titleFontWeight, color: titleColor)),
                                            Text(track.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      isCurrentlyPlayingThisTrack
                                          ? Icon(isSdkPlayerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 26, color: kFlourishAdobe)
                                          : Text(track.formattedDuration, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
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
