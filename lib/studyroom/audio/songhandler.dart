import 'dart:math';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/audio/views.dart';
import 'package:flourish_web/api/settings.dart';

class Songhandler {
  List<Song> songs = [];
  List<String> songUrls = [];

  List<Song> shuffledSongs = [];
  List<String> shuffledSongUrls = [];

  late final int id;
  int numSongs = 0;

  Future<void> init(int id) async {
    this.id = id;
    _getPlaylistInfo().then((_) {
      _getSongsInfo().then((_) {
        shuffle();
      });
    });
  }

  void shuffle() {
    if (songs.length != songUrls.length) {
      throw Exception('Songs and songUrls are not the same length');
    }

    List<int> indices = List.generate(songs.length, (index) => index);

    indices.shuffle(Random());

    shuffledSongs = [];
    shuffledSongUrls = [];

    for (int i = 0; i < songs.length; i++) {
      shuffledSongs.add(songs[indices[i]]);
      shuffledSongUrls.add(songUrls[indices[i]]);
    }
  }

  Future<void> _getPlaylistInfo() async {
    // Get playlist info from API
    Playlist playlistInfo = await requestPlaylistById(id);
    numSongs = playlistInfo.numSongs;
  }

  Future<void> _getSongsInfo() async {
    for (int i = 1; i <= numSongs; i++) {
      Song song = await requestSong(id, i);
      songs.add(song);
      songUrls.add(_getSongUrl(i));
    }
  }

  String _getSongUrl(int songId) {
    final request = buildAudioRequest({'songId': songId, 'playlistId': id});
    return 'http://$domain:$port/stream?$request';
  }
}
