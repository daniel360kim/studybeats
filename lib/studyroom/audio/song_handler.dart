import 'package:just_audio/just_audio.dart';
import 'package:flourish_web/api/audio/views.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/settings.dart';

import 'audio_controller.dart';

class SongHandler {
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(
    useLazyPreparation: false,
    children: [],
  );

  final List<Song> songsInfo = [];

  int numSongs = 0;

  final int playlistId;
  final AudioController audioController;

  SongHandler(this.playlistId, this.audioController);

  // Must be called before using the SongHandler
  Future<void> init() async {
    try {
      _getPlaylistInfo().then((_) {
        _getSongsInfo();
      });
    } catch (error) {
      // Handle errors here
      print('Error during initialization: $error');
    }
  }

  Future<void> _getPlaylistInfo() async {
    Playlist playlistInfo = await requestPlaylistById(playlistId);
    numSongs = playlistInfo.numSongs;
  }

  Future<void> _getSongsInfo() async {
    List<AudioSource> songUrls =
        []; //preload the urls before adding to the playlist helps buffering time: // See https://github.com/ryanheise/just_audio/issues/294
    for (int i = 1; i <= numSongs; i++) {
      Song songInfo = await requestSong(playlistId, i);
      songsInfo.add(songInfo);
      songUrls.add(AudioSource.uri(Uri.parse(getSongUrl(i)), tag: songInfo));
    }

    playlist.addAll(songUrls);
  }

  String getSongUrl(int songId) {
    final request =
        buildAudioRequest({'songId': songId, 'playlistId': playlistId});
    return 'http://$domain:$port/stream?$request';
  }
}
