import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/api/firebase_storage_refs.dart';
import 'package:studybeats/log_printer.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

/// A service class responsible for interacting with Firebase Storage
/// to retrieve audio data, playlist information, and waveform details
/// for the purpose of music playback.
class AudioService {
  final _logger = getLogger('Audio Service');

  // Firebase Storage reference to the audio directory.
  final _storageRef = FirebaseStorage.instance.ref(kAudioDirectoryName);

  /// Fetches information about a specific playlist.
  ///
  /// This method retrieves a list of playlists stored in Firebase Storage,
  /// then searches for and returns the playlist that matches the given [playlistId].
  ///
  /// Throws:
  /// - Exception if the playlist ID is invalid or an error occurs during processing.
  Future<Playlist> getPlaylistInfo(int playlistId) async {
    try {
      // Reference to the playlist index JSON file in Firebase Storage.
      final jsonRef = _storageRef.child(kPlaylistIndexJsonPath);
      final url = await jsonRef.getDownloadURL();

      // Fetch and decode the playlist JSON data.
      final response = await _fetchJsonData(url);
      List<dynamic> playlists = await jsonDecode(response);

      _logger.i('Found ${playlists.length} playlists in reference');

      // Convert each playlist JSON object into a Playlist object.
      List<Playlist> playlistList =
          playlists.map((playlist) => Playlist.fromJson(playlist)).toList();

      // Find the playlist that matches the given ID.
      return playlistList.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      _logger.e('Unexpected error while getting playlist info: $e');
      rethrow;
    }
  }

  /// Retrieves a list of [AudioSource] objects for the given [playlistInfo].
  ///
  /// This method fetches song metadata for the playlist, constructs URIs for the songs,
  /// and creates audio sources using the Just Audio library.
  ///
  /// Returns:
  /// - A list of [AudioSource] objects for playback.
  ///
  /// Throws:
  /// - Exception if an error occurs during URI generation or data fetching.
  Future<List<AudioSource>> getAudioSources(Playlist playlistInfo) async {
    final startTime = DateTime.now();
    try {
      _logger.i('Generating song URIs...');

      // Reference to the playlist's metadata JSON file.
      final jsonRef = _storageRef.child(playlistInfo.playlistPath);
      final url = await jsonRef.getDownloadURL();

      // Fetch and decode the song metadata.
      final response = await _fetchJsonData(url);
      List<dynamic> metadataList = await jsonDecode(response);

      if (metadataList.length != playlistInfo.numSongs) {
        _logger.w(
            'Playlist info num songs does not match the number of metadata elements found.');
      }

      // Map each metadata object to a LofiSongMetadata object.
      List<LofiSongMetadata> sources = metadataList
          .map((metadata) => LofiSongMetadata.fromJson(metadata))
          .toList();

      // Create audio sources for each song concurrently.
      List<Future<AudioSource>> audioSourceFutures =
          sources.map((source) async {
        final jsonRef = _storageRef.child(source.songPath);
        final uri = Uri.parse(await jsonRef.getDownloadURL());
        return AudioSource.uri(uri, tag: source);
      }).toList();

      final audioSources = await Future.wait(audioSourceFutures);

      final endTime = DateTime.now();
      _logger.d(
          'Getting audio sources took ${endTime.difference(startTime).inMilliseconds} ms');

      return audioSources;
    } catch (e) {
      _logger.e('Unexpected error while generating song URIs: $e');
      rethrow;
    }
  }

  /// Fetches raw JSON data from the given [url].
  ///
  /// Returns:
  /// - The response body as a string if the request is successful.
  ///
  /// Throws:
  /// - Exception if the request fails or an error occurs.
  Future<String> _fetchJsonData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        _logger
            .e('HTTP request failed with status code: ${response.statusCode}');
        throw Exception('Failed to fetch JSON data.');
      }
    } catch (e) {
      _logger.e('Unexpected error while fetching JSON data: $e');
      rethrow;
    }
  }

  /// Retrieves waveform data for the specified [waveformPath].
  /// Input:
  /// - [waveformPath] a string representing the relative path within the server
  /// this can be found in the path in [SongMetdata]
  ///
  /// Returns:
  /// - A list of integers representing the waveform data. Used to represent the
  /// waveform for a specific audio
  ///
  /// Throws:
  /// - Exception if an error occurs during data fetching or parsing.
  Future<List<int>> getWaveformData(String waveformPath) async {
    try {
      // Reference to the waveform JSON file in Firebase Storage.
      final jsonRef = _storageRef.child(waveformPath);
      final url = await jsonRef.getDownloadURL();

      // Fetch and decode the waveform JSON data.
      final response = await _fetchJsonData(url);
      final data = jsonDecode(response);

      return List.castFrom(data['data']);
    } catch (e) {
      _logger.e(
          'Unexpected error while getting waveform data for $waveformPath: $e');
      rethrow;
    }
  }

  /// Retrieves waveform metadata for the specified [waveformPath].
  ///
  /// Returns:
  /// - A [WaveformMetadata] object containing metadata details.
  ///
  /// Throws:
  /// - Exception if an error occurs during data fetching or parsing.
  Future<WaveformMetadata> getWaveformMetadata(String waveformPath) async {
    try {
      // Reference to the waveform metadata JSON file in Firebase Storage.
      final jsonRef = _storageRef.child(waveformPath);
      final url = await jsonRef.getDownloadURL();

      // Fetch and decode the waveform metadata.
      final response = await _fetchJsonData(url);
      return WaveformMetadata.fromJson(jsonDecode(response));
    } catch (e) {
      _logger.e(
          'Unexpected error while getting waveform metadata for $waveformPath: $e');
      rethrow;
    }
  }
}
