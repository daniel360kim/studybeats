import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/audio/urls.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class AudioService {
  final _logger = getLogger('Audio Service');
  final _storageRef = FirebaseStorage.instance.ref(kAudioDirectoryName);

  Future<Playlist> getPlaylistInfo(int playlistId) async {
    try {
      final jsonRef = _storageRef.child(kPlaylistIndexJsonPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);

      List<dynamic> playlists = await jsonDecode(response);

      _logger.i('Found ${playlists.length} playlists in reference');

      List<Playlist> playlistList =
          playlists.map((playlist) => Playlist.fromJson(playlist)).toList();

      return playlistList.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      _logger.e('Unexpected error while getting playlist info. $e');
      rethrow;
    }
  }

  Future<List<AudioSource>> getAudioSources(Playlist playlistInfo) async {
    final startTime = DateTime.now();
    try {
      _logger.i('Generating song uris...');

      final jsonRef = _storageRef.child(playlistInfo.playlistPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);

      List<dynamic> metadataList = await jsonDecode(response);

      if (metadataList.length != playlistInfo.numSongs) {
        _logger.w(
            'Playlist info num songs does not match number of metadata elements found');
      }

      List<SongMetadata> sources = metadataList
          .map((metadata) => SongMetadata.fromJson(metadata))
          .toList();

      List<AudioSource> audioSources = [];

      for (final source in sources) {
        final jsonRef = _storageRef.child(source.songPath); // error handle nulls TODO
        final uri = Uri.parse(await jsonRef.getDownloadURL());

        audioSources.add(AudioSource.uri(uri, tag: source));
      }

      final endTime = DateTime.now();
      _logger.d(
          'Getting audio sources took ${endTime.difference(startTime).inMilliseconds} ms');

      return audioSources;
    } catch (e) {
      _logger.e('Unexpected error while generating song uris. $e');
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

  Future<List<int>> getWaveformData(String waveformPath) async {
    try {
      final jsonRef = _storageRef.child(waveformPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);
      final data = jsonDecode(response);

      return List.castFrom(data['data']);
    } catch (e) {
      _logger.e('Unexpected error while getting waveform data. $e');
      rethrow;
    }
  }

  Future<WaveformMetadata> getWaveformMetadata(String waveformPath) async {
    try {
      final jsonRef = _storageRef.child(waveformPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);
      return WaveformMetadata.fromJson(jsonDecode(response));
    } catch (e) {
      _logger.e('Unexpected error while getting waveform metadata. $e');
      rethrow;
    }
  }
}
