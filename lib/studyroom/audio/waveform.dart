import 'dart:convert';
import 'package:flourish_web/api/audio/audio_service.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';
import 'package:shimmer/shimmer.dart';

class Waveform extends StatefulWidget {
  const Waveform({
    required this.waveformPath,
    required this.elapsedDuration,
    required this.trackTime,
    super.key,
  });

  final String waveformPath;
  final Duration elapsedDuration;
  final double trackTime;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  List<double> waveformData = [];
  bool isLoading = true; // Track loading state

  Future<List<double>> loadWaveformData(String jsonPath) async {
    final audioService = AudioService();
    final List<int> points =
        await audioService.getWaveformData(widget.waveformPath);
    List<int> filteredData = [];
    const int samples = 256;
    final double blockSize = points.length / samples;

    for (int i = 0; i < samples; i++) {
      final double blockStart = blockSize * i;
      int sum = 0;
      for (int j = 0; j < blockSize; j++) {
        sum += points[(blockStart + j).toInt()];
      }
      filteredData.add((sum / blockSize).round());
    }
    final maxNum = filteredData.reduce((a, b) => math.max(a.abs(), b.abs()));
    final double multiplier = math.pow(maxNum, -1).toDouble();

    return filteredData.map<double>((e) => (e * multiplier)).toList();
  }

  @override
  void initState() {
    super.initState();
    loadWaveformData(widget.waveformPath).then((value) {
      setState(() {
        waveformData = value;
        isLoading = false; // Set loading to false once data is loaded
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: 500,
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
      ),
      child: Center(
        child: isLoading
            ? Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 90,
                  width: 440,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
              )
            : SquigglyWaveform(
                maxDuration: convertToDuration(widget.trackTime),
                elapsedDuration: widget.elapsedDuration,
                samples: waveformData,
                height: 90,
                width: 440,
              ),
      ),
    );
  }

  Duration convertToDuration(double seconds) {
    final milliseconds = (seconds * 1000).round();
    return Duration(milliseconds: milliseconds);
  }
}
