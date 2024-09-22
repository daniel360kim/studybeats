import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/firebase_storage_refs.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:http/http.dart' as http;

class SfxService {
  final _logger = getLogger('Sfx Service');
  final _storageRef = FirebaseStorage.instance.ref(kSfxDirectoryName);

  Future<BackgroundSound> getBackgroundSoundInfo(int id) async {
    try {
      final jsonRef = _storageRef.child(kSfxIndexPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);
      List<dynamic> list = jsonDecode(response);

      _logger.i('Found ${list.length} soundfx');

      List<BackgroundSound> soundFxList =
          list.map((soundFx) => BackgroundSound.fromJson(soundFx)).toList();

      return soundFxList.firstWhere((soundfx) => soundfx.id == id);
    } catch (e) {
      _logger.e('Unexpected error while getting soundfx info. $e');
      rethrow;
    }
  }

  Future<String> getBackgroundSoundUrl(
      BackgroundSound backgroundSoundInfo) async {
    try {
      final jsonRef = _storageRef.child(backgroundSoundInfo.soundPath);
      return await jsonRef.getDownloadURL();
    } catch (e) {
      _logger.e('Unexpected error while getting background sound url. $e');
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
