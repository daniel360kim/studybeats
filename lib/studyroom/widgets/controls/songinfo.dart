import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/seekbar.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marquee/marquee.dart'; // Add this package to your pubspec.yaml

class SongInfo extends StatefulWidget {
  const SongInfo({
    required this.song,
    required this.positionData,
    required this.onSeekRequested,
    super.key,
  });

  final SongMetadata? song;
  final Stream<PositionData> positionData;
  final ValueChanged<Duration> onSeekRequested;

  @override
  State<SongInfo> createState() => _SongInfoState();
}

class _SongInfoState extends State<SongInfo> {
  bool _isHovering = false;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withOpacity(0.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 0),
                      blurRadius: 1,
                    ),
                  ],
                ),
                child: StreamBuilder<PositionData>(
                    stream: widget.positionData,
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
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 8.0,
                                      fontFamily: 'Inter',
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
            : _buildShimmerTextPlaceholder());
  }

  Widget _buildMarqueeText(String text,
      {double fontSize = 15, FontWeight fontWeight = FontWeight.normal}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: 'Inter',
            color: Colors.black,
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
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
            velocity: 50.0,
          );
        } else {
          return Text(text,
              style: TextStyle(fontSize: fontSize, fontWeight: fontWeight));
        }
      },
    );
  }

  Widget _buildShimmerTextPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 400,
        color: Colors.white,
      ),
    );
  }
}
