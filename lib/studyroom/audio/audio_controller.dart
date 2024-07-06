import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:rxdart/rxdart.dart';

import 'seekbar.dart';

class AudioController {
  final audioPlayer = AudioPlayer();

  AudioController() {
    _initPlayer();
  }

  void setPlaylist(ConcatenatingAudioSource playlist) {
    audioPlayer.setAudioSource(playlist);

    print('Audio player initialized');
  }

  void dispose() {
    audioPlayer.dispose();
  }

  int getCurrentSongIndex() {
    return audioPlayer.currentIndex ?? 0;
  }

  void _initPlayer() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Catch errors
    audioPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print(
          'A stream error occurred: $e'); // TODO: implement proper error handling
    });
  }

  Future shuffle() async {
    await audioPlayer.setShuffleModeEnabled(true);
    await audioPlayer.shuffle();
  }

  void play() async {
    try {
      await audioPlayer.play();
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  void pause() async {
    try {
      await audioPlayer.pause();
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  void seek(Duration position) async {
    try {
      await audioPlayer.seek(position, index: audioPlayer.currentIndex);
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  Future seekToIndex(int index) async {
    try {
      await audioPlayer.seek(Duration.zero, index: index);
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  Future nextSong() async {
    try {
      await audioPlayer.seekToNext();
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  Future previousSong() async {
    try {
      await audioPlayer.seekToPrevious();
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  Future setVolume(double volume) async {
    try {
      await audioPlayer.setVolume(volume);
    } catch (e) {
      print("Error: $e"); // TODO: implement proper error handling
    }
  }

  Song getCurrentSongInfo() {
    int currentIndex = audioPlayer.currentIndex ?? 0;

    final Song? songInfo = audioPlayer.sequence?[currentIndex].tag as Song?;

    return songInfo!;
  }

  List<Song> getSongOrder(int currentSongIndex) {
    final List<Song> songOrder = [];

    // Ensure sequence is not null and is not empty
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      return songOrder;
    }

    // Get current song info

    // If shuffle is enabled, return the current sequence
    
    // Add songs to songOrder list
    for (final item in audioPlayer.sequence!) {
      final Song songInfo = item.tag as Song;
      songOrder.add(songInfo);
    }

    // Find index of current song

    if (currentSongIndex == -1) {
      // Current song not found in the list
      return songOrder;
    }

    // Reorder the list based on the current song index
    final List<Song> reorderedList = [];
    final int totalSongs = songOrder.length;
    for (int i = 0; i < totalSongs; i++) {
      final int newIndex = (currentSongIndex + i) % totalSongs;
      reorderedList.add(songOrder[newIndex]);
    }

    return reorderedList;
  }

  // Gets the current position of the song for the seekbar
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          audioPlayer.positionStream,
          audioPlayer.bufferedPositionStream,
          audioPlayer.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  // Gets the current state of the player
  Stream<PlayerState> get playerStateStream => audioPlayer.playerStateStream;
}
