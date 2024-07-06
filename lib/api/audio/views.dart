import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings.dart';
import 'objects.dart';

String buildAudioRequest(Map<String, dynamic> request) {
  final requestString = request.entries.map((entry) {
    return '${entry.key}=${entry.value}';
  }).join('&');

  return requestString;
}

String buildThumbnailRequest(int songId, int playlistId) {
  final request = buildAudioRequest({'songId': songId, 'playlistId': playlistId});
  return 'https://$domain/thumbnail?$request';
}

Future<Playlist> requestPlaylistById(int id) async {
  final request = buildAudioRequest({'id': id});

  final url = 'https://$domain/playlist?$request';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Playlist.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load playlist');
  }
}

Future<Playlist> requestPlaylistByName(String name) async {
  final request = buildAudioRequest({'name': name});

  final url = 'https://$domain/playlist?$request';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Playlist.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load playlist');
  }
}

Future<Song> requestSong(int playlistId, int songId) async {
  final request =
      buildAudioRequest({'songId': songId, 'playlistId': playlistId});

  final url = 'https://$domain/song?$request';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Song.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load song');
  }
}
