import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:studybeats/api/firebase_storage_refs.dart';
import 'package:studybeats/api/timer_fx/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class TimerFxService {
  final _logger = getLogger('TimerFx Service');
  final _storageRef = FirebaseStorage.instance.ref(kTimerFxDirectoryName);

  Future<List<TimerFxData>> getTimerFxData() async {
    try {
      final jsonRef = _storageRef.child(kTimerFxIndexPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);

      List<dynamic> timerFxDataList = await jsonDecode(response);

      _logger.i('Found ${timerFxDataList.length} timer fx in reference');

      List<TimerFxData> timerFxList = timerFxDataList
          .map((timerFxData) => TimerFxData.fromJson(timerFxData))
          .toList();
      return timerFxList;
    } catch (e) {
      _logger.e('Unexpected error while getting timer fx data. $e');
      rethrow;
    }
  }

  Future<AudioSource> getAudioSource(TimerFxData timerFxData) async {
    try {
      final jsonRef = _storageRef.child(timerFxData.soundPath);
      final url = await jsonRef.getDownloadURL();

      return AudioSource.uri(Uri.parse(url));
    } catch (e) {
      _logger.e('Unexpected error while getting audio source. $e');
      rethrow;
    }
  }

  Future<String> _fetchJsonData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        _logger
            .e('Http request failed with status code: ${response.statusCode}');
        throw Exception();
      }
    } catch (e) {
      _logger.e('Unexpected error while fetching json data .$e');
      rethrow;
    }
  }
}
