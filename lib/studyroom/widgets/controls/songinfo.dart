import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/seekbar.dart';
import 'package:flutter/material.dart';

class SongInfo extends StatefulWidget {
  const SongInfo({
    required this.song,
    required this.positionData,
    required this.onSeekRequested,
    super.key,
  });

  final Song song;
  final Stream<PositionData> positionData;
  final ValueChanged<Duration> onSeekRequested;

  @override
  State<SongInfo> createState() => _SongInfoState();
}

class _SongInfoState extends State<SongInfo> {
  bool _isHovering = false;

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
      child: Container(
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
                  Text(
                    widget.song.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    widget.song.artist,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Inter',
                    ),
                  ),
                  _isHovering
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$')
                                    .firstMatch("$remaining")
                                    ?.group(1) ??
                                '$remaining',
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
                          positionData?.bufferedPosition ?? Duration.zero,
                      onChangeEnd: (newPosition) =>
                          widget.onSeekRequested(newPosition),
                      isHovering: _isHovering,
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }
}
