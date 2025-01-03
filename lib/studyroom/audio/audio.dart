import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:studybeats/api/audio/audio_service.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/objects.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';
import 'package:flutter/foundation.dart';
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

  SongCloudInfoHandler _cloudInfoHandler = SongCloudInfoHandler(playlistId: 0);

  TimerService songDurationTimer = TimerService();

  //List<SongMetadata> audioPlayer.sequence! = [];
  int currentSongIndex = 0;

  bool isAdvance =
      false; // prevents autoAdvance position discontinuity from triggering when shuffling

  final _playlist =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);

  final _authService = AuthService();

  void initPlayer() async {
    try {
      final service = AudioService();

      final playlist = await service.getPlaylistInfo(playlistId);
      final audioSources = await service.getAudioSources(playlist);
      await _playlist.addAll(audioSources);

      await audioPlayer.setAudioSource(_playlist);

      // Get info about the audioPlayer.sequence! from the cloud database based on the playlistId
      _cloudInfoHandler = SongCloudInfoHandler(playlistId: playlistId);

      if (_authService.isUserLoggedIn()) await _cloudInfoHandler.init();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      // Listen to errors durin playback
      audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          _logger.e('$e', stackTrace: stackTrace);
        },
      );

      audioPlayer.positionDiscontinuityStream.listen((discontinuity) {
        if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
          if (isAdvance) {
            isAdvance = false;
            return;
          }
          isLoaded.value = false;
          if (currentSongIndex + 1 < audioPlayer.sequence!.length) {
            currentSongIndex = currentSongIndex + 1;
          } else {
            currentSongIndex = 0;
          }
          isLoaded.value = true;
        }
      });

      isLoaded.value = true;
    } catch (e) {
      _logger.e('Error with songcloudinfo handler');
      // TODO handle this error
    }
  }

  void dispose() {
    audioPlayer.pause();
    audioPlayer.dispose();

    // Log the song end in the cloud database
    if (_authService.isUserLoggedIn()) {
      _cloudInfoHandler.onSongEnd(currentSongIndex, getSongPlayedDuration());
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
    if (!_authService.isUserLoggedIn()) {
      return;
    }
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

  void setSpeed(double speed) async {
    try {
      await audioPlayer.setSpeed(speed);
    } catch (e) {
      _logger.e('Audio set speed to $speed failed');
      rethrow;
    }
  }

  Future seekToIndex(int index) async {
    if (_authService.isUserLoggedIn()) {
      await _cloudInfoHandler.onSongEnd(
          currentSongIndex, getSongPlayedDuration());
    }

    isLoaded.value = false;
    try {
      await audioPlayer.seek(Duration.zero, index: index);
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

    if (currentSongIndex + 1 < audioPlayer.sequence!.length) {
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
      prevIndex = audioPlayer.sequence!.length - 1;
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
    isAdvance = true;
    // Get the current sequence of AudioSources
    final sequence = audioPlayer.sequence;

    if (sequence == null || sequence.isEmpty) {
      return; // No songs to shuffle
    }

    // Shuffle the audio sources
    final random = Random();
    final shuffledSequence =
        List<AudioSource>.from(sequence); // Create a mutable copy
    shuffledSequence.shuffle(random); // Shuffle the list

    // Replace the current sequence with the shuffled sequence
    await audioPlayer
        .setAudioSource(ConcatenatingAudioSource(children: shuffledSequence));

    // Select a new random song index
    currentSongIndex =
        random.nextInt(shuffledSequence.length); // Select random index

    try {
      await seekToIndex(currentSongIndex);
      print('');
    } catch (e) {
      _logger.e('Failed to seek to shuffled song: $e');
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

  SongMetadata? getCurrentSongInfo() {
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      return null;
    }
    return audioPlayer.sequence![currentSongIndex].tag;
  }

  SongMetadata getNextSongInfo() {
    if (currentSongIndex + 1 < audioPlayer.sequence!.length) {
      return audioPlayer.sequence![currentSongIndex + 1].tag;
    }

    return audioPlayer.sequence![0].tag;
  }

  SongMetadata getPreviousSongInfo() {
    if (currentSongIndex - 1 >= 0) {
      return audioPlayer.sequence![currentSongIndex - 1].tag;
    }
    return audioPlayer.sequence![audioPlayer.sequence!.length - 1].tag;
  }

  // Caller should check if the user is logged in before calling this function
  Future getCurrentSongCloudInfo() async {
    return await _cloudInfoHandler.getSongCloudInfo(currentSongIndex);
  }

  List<SongMetadata> getSongOrder() {
    // Get the current sequence of audio sources
    final sequence = audioPlayer.sequence;

    if (sequence == null || sequence.isEmpty) {
      return []; // Return an empty list if no songs are available
    }

    // Create a list to hold the song order
    List<SongMetadata> orderedSongs = [];

    // Add songs starting from the current song index to the end
    for (int i = currentSongIndex + 1; i < sequence.length - 1; i++) {
      orderedSongs.add(sequence[i].tag);
    }

    // Add songs from the beginning of the list to the current song index
    for (int i = 0; i < currentSongIndex; i++) {
      orderedSongs.add(sequence[i].tag);
    }

    return orderedSongs;
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
