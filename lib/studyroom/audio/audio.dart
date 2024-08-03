import 'dart:convert';
import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/seekbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class Audio {
  Audio({
    required this.playlistId,
  });

  final _logger = getLogger('AudioController');

  final int playlistId;
  final audioPlayer = AudioPlayer();
  final ValueNotifier<bool> isLoaded = ValueNotifier<bool>(false);

  late final SongCloudInfoHandler _cloudInfoHandler;

  TimerService songDurationTimer = TimerService();

  List<Song> songs = [];
  int currentSongIndex = 0;
  Playlist playlistInfo = const Playlist(
    id: 0,
    name: '',
    numSongs: 0,
    playlistPath: '',
  );

  void initPlayer() async {
    try {
      // Get the playlist info from the JSON file
      playlistInfo = await getPlaylistInfo();
      // Get the appropriate song data from the playlistInfo
      songs = await getSongsInfo(playlistInfo);

      // Get info about the songs from the cloud database based on the playlistId
      _cloudInfoHandler = SongCloudInfoHandler(playlistId: playlistId);
      await _cloudInfoHandler.init();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      // Listen to errors durin playback
      audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          _logger.e('$e', stackTrace: stackTrace);
        },
      );

      _setAudioSourceAsStream(songs[currentSongIndex].songPath);

      // Go to the next song when the current song finishes
      audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          nextSong();
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  void dispose() {
    audioPlayer.pause();
    audioPlayer.dispose();

    // Log the song end in the cloud database
    _cloudInfoHandler.onSongEnd(currentSongIndex, getSongPlayedDuration());
  }

  Future<Playlist> getPlaylistInfo() async {
    try {
      String json =
          await rootBundle.loadString('assets/audio/index/playlists.json');

      List<dynamic> playlists = await jsonDecode(json);
      List<Playlist> playlistList =
          playlists.map((playlist) => Playlist.fromJson(playlist)).toList();

      return playlistList.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      _logger.e('Playlist info asset not found. $e');
      rethrow;
    }
  }

  Future<List<Song>> getSongsInfo(Playlist playlistInfo) async {
    try {
      String json = await rootBundle.loadString(playlistInfo.playlistPath);
      List<dynamic> songs = await jsonDecode(json);
      List<Song> songList = songs.map((song) => Song.fromJson(song)).toList();

      return songList;
    } catch (e) {
      _logger.e('Song info for playlist ${playlistInfo.name} not found. $e');
      rethrow;
    }
  }

  void play() async {
    songDurationTimer.start();
    try {
      await audioPlayer.play();
    } catch (e) {
      _logger.e('Audio play failed. $e');
      rethrow;
    }
  }

  void pause() async {
    songDurationTimer.stop();
    try {
      await audioPlayer.pause();
    } catch (e) {
      _logger.e('Audio pause failed. $e');
      rethrow;
    }
  }

  Future setFavorite(bool isFavorite) async {
    try {
      await _cloudInfoHandler.setFavorite(currentSongIndex, isFavorite);
    } catch (e) {
      rethrow;
    }
  }

  Duration getSongPlayedDuration() {
    return songDurationTimer.getElapsed();
  }

  void seek(Duration position) async {
    try {
      await audioPlayer.seek(position);
    } catch (e) {
      _logger.e('Audio seek to ${position.inMilliseconds} failed. $e');
      rethrow;
    }
  }

  void _setAudioSourceAsStream(String path) async {
    try {
      var loadStartTime = DateTime.now();
      final file = await rootBundle.load(path);
      var loadEndTime = DateTime.now();
      var loadDuration = loadEndTime.difference(loadStartTime);
      _logger.d('rootBundle.load time: ${loadDuration.inMilliseconds}ms');

      var streamStartTime = DateTime.now();
      final streamAudioSource = BufferAudioSource(file.buffer.asUint8List());
      var streamEndTime = DateTime.now();
      var streamDuration = streamEndTime.difference(streamStartTime);
      _logger.d(
          'BufferAudioSource creation time: ${streamDuration.inMilliseconds}ms');

      var setStartTime = DateTime.now();
      final audioSource = streamAudioSource;
      await audioPlayer.setAudioSource(audioSource, preload: true);
      var setEndTime = DateTime.now();
      var setDuration = setEndTime.difference(setStartTime);
      _logger.d(
          'audioPlayer.setAudioSource time: ${setDuration.inMilliseconds}ms');

      isLoaded.value = true;
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  void setSpeed(double speed) async {
    try {
      await audioPlayer.setSpeed(speed);
    } catch (e) {
      _logger.e('Audio set speed to $speed failed');
      rethrow;
    }
  }

  Future seekToIndex(int index) async {
    await _cloudInfoHandler.onSongEnd(
        currentSongIndex, getSongPlayedDuration());

    isLoaded.value = false;
    try {
      _setAudioSourceAsStream(songs[index].songPath);
      await audioPlayer.seek(Duration.zero);
      currentSongIndex = index;

      songDurationTimer.reset();

      // If paused, don't start the timer
      if (audioPlayer.playerState.playing) {
        songDurationTimer.start();
      }

      isLoaded.value = true;
    } catch (e) {
      _logger.e('Audio seek to $index failed');
      rethrow;
    }
  }

  Future nextSong() async {
    isLoaded.value = false;
    int nextIndex = 0;

    if (currentSongIndex + 1 < songs.length) {
      nextIndex = currentSongIndex + 1;
    } else {
      nextIndex = 0;
    }

    try {
      await seekToIndex(nextIndex).then((value) => isLoaded.value = true);
    } catch (e) {
      rethrow;
    }
  }

  Future previousSong() async {
    isLoaded.value = false;
    int prevIndex = 0;

    if (currentSongIndex - 1 >= 0) {
      prevIndex = currentSongIndex - 1;
    } else {
      prevIndex = songs.length - 1;
    }
    try {
      await seekToIndex(prevIndex).then((value) => isLoaded.value = true);
    } catch (e) {
      rethrow;
    }
  }

  Future setVolume(double volume) async {
    try {
      await audioPlayer.setVolume(volume);
    } catch (e) {
      _logger.e('Audio set volume to $volume failed');
      rethrow;
    }
  }

  void shuffle() async {
    songs.shuffle();
    try {
      await seekToIndex(currentSongIndex);
    } catch (e) {
      rethrow;
    }
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

  Song getCurrentSongInfo() {
    return songs[currentSongIndex];
  }

  Song getNextSongInfo() {
    if (currentSongIndex + 1 < songs.length) {
      return songs[currentSongIndex + 1];
    }

    return songs[0];
  }

  Song getPreviousSongInfo() {
    if (currentSongIndex - 1 >= 0) {
      return songs[currentSongIndex - 1];
    }
    return songs[songs.length - 1];
  }

  Future getCurrentSongCloudInfo() async {
    return await _cloudInfoHandler.getSongCloudInfo(currentSongIndex);
  }

  List<Song> getSongOrder() {
    return songs.sublist(currentSongIndex + 1) +
        songs.sublist(0, currentSongIndex);
  }
}

class BufferAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  BufferAudioSource(this._buffer) : super();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) {
    start = start ?? 0;
    end = end ?? _buffer.length;

    return Future.value(
      StreamAudioResponse(
        sourceLength: _buffer.length,
        contentLength: end - start,
        offset: start,
        contentType: 'audio/wav',
        stream:
            Stream.value(List<int>.from(_buffer.skip(start).take(end - start))),
      ),
    );
  }
}

class TimerService {
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  // Start the timer
  void start() {
    if (!_isRunning) {
      _startTime = DateTime.now();
      _isRunning = true;
    }
  }

  // Stop the timer
  void stop() {
    if (_isRunning) {
      _elapsed += DateTime.now().difference(_startTime!);
      _startTime = null;
      _isRunning = false;
    }
  }

  // Reset the timer
  void reset() {
    _startTime = null;
    _elapsed = Duration.zero;
    _isRunning = false;
  }

  // Get the elapsed duration
  Duration getElapsed() {
    if (_isRunning && _startTime != null) {
      return _elapsed + DateTime.now().difference(_startTime!);
    }
    return _elapsed;
  }
}
