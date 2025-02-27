import 'dart:convert';
import 'dart:ui';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:http/http.dart' as http;

class SceneService {
  final _logger = getLogger('Scene API Service');
  final _storageRef = FirebaseStorage.instance.ref('scenes');

  Future<List<SceneData>> getSceneData() async {
    try {
      final jsonRef = _storageRef.child('index.json');
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);

      List<dynamic> scenes = await jsonDecode(response);

      _logger.i('Found ${scenes.length} scenes in reference');

      List<SceneData> scenesList =
          scenes.map((scene) => SceneData.fromJson(scene)).toList();

      return scenesList;
    } catch (e) {
      _logger.e('Unexpected error while getting scenes info. $e');
      rethrow;
    }
  }

  Future<String> getBackgroundImageUrl(SceneData scene) async {
    try {
      final jsonRef = _storageRef.child(scene.scenePath);
      return await jsonRef.getDownloadURL();
    } catch (e) {
      _logger.e(
          'Unknown error while getting background image url for ${scene.name} $e');
      rethrow;
    }
  }

  Future<String> getThumbnailImageUrl(SceneData scene) async {
    try {
      final jsonRef = _storageRef.child(scene.thumbnailPath);
      return await jsonRef.getDownloadURL();
    } catch (e) {
      _logger.e(
          'Unknown error while getting thumbnail image url for ${scene.name} $e');
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
