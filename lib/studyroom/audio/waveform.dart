import 'dart:convert';

import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';

class Waveform extends StatefulWidget {
  const Waveform(
      {required this.song, required this.elapsedDuration, super.key});

  final Song song;
  final Duration elapsedDuration;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  List<double> waveformData = [];

  Future<List<double>> loadWaveformData(String jsonPath) async {
    final json = await rootBundle.loadString(jsonPath);
    final data = jsonDecode(json);
    final List<int> points = List.castFrom(data['data']);
    List<int> filteredData = [];
    // Change this value to number of audio samples you want.
    // Values between 256 and 1024 are good for showing [RectangleWaveform] and [SquigglyWaveform]
    // While the values above them are good for showing [PolygonWaveform]
    const int samples = 256;
    final double blockSize = points.length / samples;

    for (int i = 0; i < samples; i++) {
      final double blockStart =
          blockSize * i; // the location of the first sample in the block
      int sum = 0;
      for (int j = 0; j < blockSize; j++) {
        sum = sum +
            points[(blockStart + j).toInt()]
                .toInt(); // find the sum of all the samples in the block
      }
      filteredData.add((sum / blockSize)
          .round() // take the average of the block and add it to the filtered data
          .toInt()); // divide the sum by the block size to get the average
    }
    final maxNum = filteredData.reduce((a, b) => math.max(a.abs(), b.abs()));

    final double multiplier = math.pow(maxNum, -1).toDouble();

    return filteredData.map<double>((e) => (e * multiplier)).toList();
  }

  @override
  void initState() {
    super.initState();
    loadWaveformData(widget.song.waveformPath).then((value) {
      setState(() {
        waveformData = value;
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
          child: SquigglyWaveform(
            maxDuration: convertToDuration(widget.song.duration),
            elapsedDuration: widget.elapsedDuration,
            samples: waveformData,
            height: 90,
            width: 440,
          ),
        ));
  }

  Duration convertToDuration(double seconds) {
    final milliseconds = (seconds * 1000).round();
    return Duration(milliseconds: milliseconds);
  }
}
