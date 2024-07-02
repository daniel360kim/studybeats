import 'package:audioplayers/audioplayers.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/songhandler.dart';

class AudioController {
  final player = AudioPlayer();
  late final Songhandler songhandler;
  Duration currentPos = Duration.zero;

  int currentSongIndex = 0;

  void initPlayer(Songhandler songhandler) async {
    this.songhandler = songhandler;
    player.setSourceUrl(songhandler.songUrls[currentSongIndex]);
    player.onPlayerComplete.listen((_) => next());
    player.onPositionChanged.listen((Duration pos) => currentPos = pos);

    await player.play(UrlSource(
      songhandler.songUrls[currentSongIndex],
    ));
  }

  void dispose() {
    player.dispose();
  }

  void play() async {
    await player.resume();
  }

  void pause() async {
    await player.pause();
  }

  void next() async {
    if (currentSongIndex == songhandler.songUrls.length - 1) {
      currentSongIndex = 0;
    } else {
      currentSongIndex++;
    }
    await player.setSourceUrl(songhandler.songUrls[currentSongIndex]);
  }

  void previous() async {
    if (currentPos > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      if (currentSongIndex == 0) {
        currentSongIndex = songhandler.songUrls.length - 1;
      } else {
        currentSongIndex--;
      }
      await player.setSourceUrl(songhandler.songUrls[currentSongIndex]);
    }
  }

  Song getCurrentSongInfo() {
    return songhandler.songs[currentSongIndex];
  }
}
