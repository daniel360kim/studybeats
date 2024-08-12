import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flourish_web/api/audio/itunes_service.dart';
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

  Future<List<SongReference>> getSongReferences(Playlist playlistInfo) async {
    try {
      final jsonRef = _storageRef.child(playlistInfo.playlistPath);
      final url = await jsonRef.getDownloadURL();

      final response = await _fetchJsonData(url);
      List<dynamic> songs = await jsonDecode(response);
      List<SongReference> songRefList =
          songs.map((song) => SongReference.fromJson(song)).toList();

      _logger.i(
          'Found ${songRefList.length} songs in playlist ${playlistInfo.name}');

      if (songRefList.length != playlistInfo.numSongs) {
        _logger.w(
            'Parsed songs for playlist ${playlistInfo.name} does not have the same length as parsed playlist info');
      }
      return songRefList;
    } catch (e) {
      _logger.e('Unexpected error while parsing song list: $e');
      rethrow;
    }
  }

  Future<List<AudioSource>> getAudioSources(Playlist playlistInfo) async {
    final startTime = DateTime.now();
    try {
      _logger.i('Generating song uris...');
      final songRefs = await getSongReferences(playlistInfo);

      List<AudioSource> sources = [];
      final itunesService = ITunesService();

      // Prepare a list of future download URL requests
      final List<Future<String>> urlFutures = songRefs.map((ref) {
        final songRef = _storageRef.child(ref.path!);
        return songRef.getDownloadURL();
      }).toList();

      // Await all futures to resolve simultaneously
      final List<String> urls = await Future.wait(urlFutures);

      // Process each song reference with its corresponding URL
      for (int i = 0; i < songRefs.length; i++) {
        final ref = songRefs[i];
        final uri = Uri.parse(urls[i]);
        final songMetadata =
            await itunesService.getSongMetadata(ref.appleLink!, ref);

        sources.add(AudioSource.uri(uri, tag: songMetadata));
      }

      final endTime = DateTime.now();
      _logger.d(
          'Getting audio sources took ${endTime.difference(startTime).inMilliseconds} ms');

      return sources;
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
