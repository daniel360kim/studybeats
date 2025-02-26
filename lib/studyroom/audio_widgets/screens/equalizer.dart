import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/studyroom/audio/waveform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';

enum Speed { x_5, x1, x1_5, x2 }

Map<Speed, double> speedValues = {
  Speed.x_5: 0.5,
  Speed.x1: 1.0,
  Speed.x1_5: 1.5,
  Speed.x2: 2.0,
};

class EqualizerControls extends StatefulWidget {
  const EqualizerControls({
    super.key,
    required this.song,
    required this.elapsedDuration,
    required this.onSpeedChange,
  });

  final SongMetadata? song;
  final Duration elapsedDuration;
  final ValueChanged<double> onSpeedChange;

  @override
  State<EqualizerControls> createState() => _EqualizerControlsState();
}

class _EqualizerControlsState extends State<EqualizerControls> {
  Speed _speed = Speed.x1;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(40.0),
      topRight: Radius.circular(40.0),
    );

    return SizedBox(
      width: 500,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(170, 170, 170, 0.7),
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                buildHeader(),
                const SizedBox(height: 10),
                widget.song == null
                    ? _buildShimmerWaveformPlaceholder()
                    : Waveform(
                        key: ValueKey(widget.song!.waveformPath),
                        waveformPath: widget.song!.waveformPath,
                        trackTime: widget.song!.trackTime,
                        elapsedDuration: widget.elapsedDuration,
                      ),
                const SizedBox(height: 10),
                buildSpeedControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String getUpscaledImage(String artworkUrl100) {
    return artworkUrl100.replaceAll('100x100', '500x500');
  }
  Widget buildHeader() {
    return Container(
      width: 500,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            elevation: 3,
            child: widget.song == null
                ? _buildShimmerThumbnailPlaceholder()
                : CachedNetworkImage(
                    imageUrl: getUpscaledImage(widget.song!.artworkUrl100),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 20),
          widget.song == null
              ? _buildShimmerTextPlaceholder()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.song!.trackName,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.song!.artistName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget buildSpeedControls() {
    return SizedBox(
      width: 500,
      child: CupertinoSlidingSegmentedControl<Speed>(
        backgroundColor: Colors.white.withOpacity(0.7),
        children: const {
          Speed.x_5: Text('0.5x'),
          Speed.x1: Text('1x'),
          Speed.x1_5: Text('1.5x'),
          Speed.x2: Text('2x'),
        },
        groupValue: _speed,
        onValueChanged: (value) {
          setState(() {
            _speed = value!;
            widget.onSpeedChange(speedValues[value]!);
          });
        },
      ),
    );
  }

  Widget _buildShimmerThumbnailPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 100,
        height: 100,
        color: Colors.white,
      ),
    );
  }

  Widget _buildShimmerTextPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 150,
            height: 25,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 100,
            height: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerWaveformPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 50,
        color: Colors.white,
      ),
    );
  }
}
