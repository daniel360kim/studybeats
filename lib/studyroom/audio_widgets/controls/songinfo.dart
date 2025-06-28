import 'dart:async';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marquee/marquee.dart'; // Add this package to your pubspec.yaml
import 'package:studybeats/theme_provider.dart';

class SongInfo extends StatefulWidget {
  const SongInfo({
    required this.song,
    required this.positionStream,
    required this.onSeekRequested,
    super.key,
  });

  final DisplayTrackInfo? song;
  final Stream<PositionData> positionStream;
  final ValueChanged<Duration> onSeekRequested;

  @override
  State<SongInfo> createState() => _SongInfoState();
}

class _SongInfoState extends State<SongInfo> {
  bool _isHovering = false;
  bool _showLoadingError = false;


  @override
  void initState() {
    super.initState();

  }

  @override
  void didUpdateWidget(SongInfo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If song changed from null to non-null, reset error state
    if (oldWidget.song == null && widget.song != null) {
      setState(() {
        _showLoadingError = false;
      });

    }


  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return MouseRegion(
        onEnter: (_) {
          setState(() {
            _isHovering = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isHovering = false;
          });
        },
        child: widget.song != null
            ? Container(
                width: 400,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: theme.songInfoBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 0),
                      blurRadius: 1,
                    ),
                  ],
                ),
                child: StreamBuilder<PositionData>(
                    stream: widget.positionStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data;
                      final position = positionData?.position ?? Duration.zero;
                      final duration = positionData?.duration ?? Duration.zero;
                      final remaining = duration - position;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          widget.song == null
                              ? _buildShimmerTextPlaceholder()
                              : _buildMarqueeText(widget.song!.trackName,
                                  fontSize: 12, fontWeight: FontWeight.w600),
                          widget.song == null
                              ? _buildShimmerTextPlaceholder()
                              : _buildMarqueeText(widget.song!.artistName,
                                  fontSize: 9, fontWeight: FontWeight.w300),
                          _isHovering
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _formatDuration(remaining),
                                    style: GoogleFonts.inter(
                                      color: theme.songInfoTextColor,
                                      fontSize: 8.0,
                                    ),
                                  ),
                                )
                              : const SizedBox(height: 11),
                          SizedBox(
                            height: 15,
                            child: SeekBar(
                              duration: duration,
                              position: position,
                              bufferedPosition:
                                  positionData?.bufferedPosition ??
                                      Duration.zero,
                              onChangeEnd: (newPosition) =>
                                  widget.onSeekRequested(newPosition),
                              isHovering: _isHovering,
                            ),
                          ),
                        ],
                      );
                    }),
              )
            : _showLoadingError
                ? _buildErrorPlaceholder()
                : _buildShimmerTextPlaceholder());
  }

  Widget _buildMarqueeText(String text,
      {double fontSize = 15, FontWeight fontWeight = FontWeight.normal}) {
    final theme = Provider.of<ThemeProvider>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: text,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: theme.songInfoTextColor,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines) {
          return Marquee(
            text: text,
            style:
                GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: theme.songInfoTextColor),
            velocity: 50.0,
          );
        } else {
          return Text(text,
              style: GoogleFonts.inter(
                  fontSize: fontSize, fontWeight: fontWeight, color: theme.songInfoTextColor));
        }
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 400,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.8),
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                size: 20, color: Colors.red.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load audio. Try refreshing.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerTextPlaceholder() {
    final theme = Provider.of<ThemeProvider>(context);
    final audioSourceProvider =
        Provider.of<AudioSourceSelectionProvider>(context, listen: false);
    final currentSource = audioSourceProvider.currentSource;
    if (currentSource == AudioSourceType.lofi) {
      return Shimmer.fromColors(
        baseColor: theme.shimmerBaseColor,
        highlightColor: theme.shimmerHighlightColor,
        child: Container(
          width: 400,
          color: Colors.white,
        ),
      );
    } else {
      return Container(
        width: 400,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100.withOpacity(0.65),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center, // Ensure vertical alignment
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.music_off_rounded,
                  size: 20, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No song selected',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
