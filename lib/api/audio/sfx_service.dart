import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/api/firebase_storage_refs.dart';
import 'package:studybeats/log_printer.dart';
import 'package:http/http.dart' as http;

/// A service class for managing background sound effects (SFX).
///
/// This class handles interactions with Firebase Cloud Storage to fetch
/// metadata and URLs for sound effects used in the application.
class SfxService {
  final _logger = getLogger('Sfx Service');

  // Reference to the SFX directory in Firebase Cloud Storage.
  final _storageRef = FirebaseStorage.instance.ref(kSfxDirectoryName);

  /// Fetches metadata for a specific background sound by its ID.
  ///
  /// This method retrieves the list of available background sounds from
  /// Firebase Cloud Storage, parses the metadata, and returns the sound
  /// effect that matches the given [id].
  ///
  /// [id] - The unique identifier of the background sound to fetch.
  ///
  /// Returns:
  /// - A [BackgroundSound] object containing metadata for the sound.
  ///
  /// Throws:
  /// - Exception if the ID is invalid or an error occurs during processing.
  Future<BackgroundSound> getBackgroundSoundInfo(int id) async {
    try {
      // Retrieve the JSON index file from the SFX directory.
      final jsonRef = _storageRef.child(kSfxIndexPath);
      final url = await jsonRef.getDownloadURL();

      // Fetch and parse the JSON data.
      final response = await _fetchJsonData(url);
      List<dynamic> list = jsonDecode(response);

      _logger.i('Found ${list.length} sound effects.');

      // Convert the parsed JSON into a list of BackgroundSound objects.
      List<BackgroundSound> soundFxList =
          list.map((soundFx) => BackgroundSound.fromJson(soundFx)).toList();

      // Find the sound effect matching the provided ID.
      return soundFxList.firstWhere((soundfx) => soundfx.id == id);
    } catch (e) {
      _logger.e('Unexpected error while getting sound effect info. $e');
      rethrow;
    }
  }

  /// Fetches the URL for a given background sound.
  ///
  /// This method retrieves the download URL for the specified sound effect
  /// using its metadata's [soundPath].
  ///
  /// [backgroundSoundInfo] - The [BackgroundSound] object containing the path.
  ///
  /// Returns:
  /// - A [String] representing the download URL of the sound effect.
  ///
  /// Throws:
  /// - Exception if an error occurs while fetching the URL.
  Future<String> getBackgroundSoundUrl(
      BackgroundSound backgroundSoundInfo) async {
    try {
      // Retrieve the specific sound file from the SFX directory.
      final jsonRef = _storageRef.child(backgroundSoundInfo.soundPath);
      return await jsonRef.getDownloadURL();
    } catch (e) {
      _logger.e('Unexpected error while getting background sound URL. $e');
      rethrow;
    }
  }

  /// Internal method to fetch JSON data from a given URL.
  ///
  /// This method sends an HTTP GET request to the specified URL and returns
  /// the response body as a [String] if the request is successful.
  ///
  /// [url] - The URL to fetch the JSON data from.
  ///
  /// Returns:
  /// - A [String] containing the JSON response body.
  ///
  /// Throws:
  /// - Exception if the HTTP request fails or an error occurs during parsing.
  Future<String> _fetchJsonData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      // Check if the HTTP request was successful.
      if (response.statusCode == 200) {
        return response.body;
      } else {
        _logger
            .e('HTTP request failed with status code: ${response.statusCode}');
        throw Exception('Failed to fetch JSON data.');
      }
    } catch (e) {
      _logger.e('Unexpected error while fetching JSON data. $e');
      rethrow;
    }
  }
}
