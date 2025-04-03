import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:studybeats/api/audio/audio_service.dart';
import 'package:studybeats/api/audio/cloud_info/cloud_info_service.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';

class Audio {
  Audio({
    required this.playlistId,
    required this.onError,
  });

  final _logger = getLogger('AudioController');
  final _cloudInfoService = SongCloudInfoService();

  // The playlist id for which this instance is created.
  int playlistId;
  final VoidCallback onError;
  final audioPlayer = AudioPlayer();
  final ValueNotifier<bool> isLoaded = ValueNotifier<bool>(false);

  TimerService songDurationTimer = TimerService();

  // Index of the current song.
  int currentSongIndex = 0;

  bool isAdvance = false; // prevents autoAdvance position discontinuity issues

  final _playlist =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);

  Future<void> initPlayer() async {
    try {
      // Initialize the audio service to fetch playlist information
      final service = AudioService();
      await _cloudInfoService.init();

      // Retrieve the playlist metadata using the provided playlist ID
      final playlist = await service.getPlaylistInfo(playlistId);

      // Fetch audio sources associated with the playlist
      final audioSources = await service.getAudioSources(playlist);

      // Add the fetched audio sources to the concatenating audio source
      await _playlist.addAll(audioSources);

      // Set the concatenating audio source as the source for the audio player
      await audioPlayer.setAudioSource(_playlist);

      // Configure the audio session for speech settings, ensuring proper audio playback
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      // Set up a listener for playback events to log errors and handle them appropriately
      audioPlayer.playbackEventStream.listen(
        (event) {
          // Handle playback events if necessary (e.g., logging, UI updates)
        },
        onError: (Object e, StackTrace stackTrace) {
          _logger.e('$e', stackTrace: stackTrace);
        },
      );

      // Listen for position discontinuities, such as song transitions or skips
      audioPlayer.positionDiscontinuityStream.listen((discontinuity) async {
        if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
          await updateAndResetDurationLog();
          if (isAdvance) {
            isAdvance = false; // Prevent unnecessary updates when shuffling
            return;
          }

          isLoaded.value = false;

          // Update currentSongIndex safely
          if (currentSongIndex + 1 < (audioPlayer.sequence?.length ?? 0)) {
            currentSongIndex = currentSongIndex + 1;
          } else {
            currentSongIndex = 0;
          }

          isLoaded.value = true;
        }
      });

      isLoaded.value = true;
    } catch (e) {
      _logger.e('Error initializing audio player: $e');
      onError();
    }
  }

  void dispose() async {
    audioPlayer.pause();
    audioPlayer.dispose();
    try {
      await updateAndResetDurationLog();
    } catch (e) {
      _logger.e('Duration update failed during dispose');
      // No rethrow since the user is going to another page
    }
  }

  /// Stops timer, logs the new duration and resets.
  Future<void> updateAndResetDurationLog() async {
    try {
      // Check if the sequence is available and currentSongIndex is valid.
      if (audioPlayer.sequence == null ||
          audioPlayer.sequence!.isEmpty ||
          currentSongIndex >= audioPlayer.sequence!.length) {
        _logger.e('No valid song found for duration update.');
        return;
      }

      final song = audioPlayer.sequence![currentSongIndex].tag as SongMetadata;
      songDurationTimer.stop();
      final elapsed = songDurationTimer.getElapsed();
      songDurationTimer.reset();
      await _cloudInfoService.updateSongDuration(playlistId, song, elapsed);

      if (audioPlayer.playing) {
        songDurationTimer.start();
      }
    } catch (e) {
      _logger.e('Failed to update song duration: $e');
      onError();
    }
  }

  Future play() async {
    songDurationTimer.start();
    try {
      await audioPlayer.play();
    } catch (e) {
      _logger.e('Audio play failed. $e');
      onError();
    }
  }

  void pause() async {
    try {
      await updateAndResetDurationLog();
      await audioPlayer.pause();
    } catch (e) {
      _logger.e('Audio pause failed. $e');
      onError();
    }
  }

  void seek(Duration position) async {
    try {
      await audioPlayer.seek(position);
    } catch (e) {
      _logger.e('Audio seek to ${position.inMilliseconds} failed. $e');
      onError();
    }
  }

  void setSpeed(double speed) async {
    try {
      await audioPlayer.setSpeed(speed);
    } catch (e) {
      _logger.e('Audio set speed to $speed failed');
      onError();
    }
  }

  Future seekToIndex(int index) async {
    isLoaded.value = false;
    try {
      await updateAndResetDurationLog();
      await audioPlayer.seek(Duration.zero, index: index);
      currentSongIndex = index;
      isLoaded.value = true;
    } catch (e) {
      _logger.e('Audio seek to $index failed');
      onError();
    }
  }

  Future nextSong() async {
    isLoaded.value = false;
    int nextIndex = 0;

    if (currentSongIndex + 1 < (audioPlayer.sequence?.length ?? 0)) {
      nextIndex = currentSongIndex + 1;
    } else {
      nextIndex = 0;
    }

    try {
      await seekToIndex(nextIndex).then((_) => isLoaded.value = true);
    } catch (e) {
      onError();
    }
  }

  Future previousSong() async {
    isLoaded.value = false;
    int prevIndex = 0;

    if (currentSongIndex - 1 >= 0) {
      prevIndex = currentSongIndex - 1;
    } else {
      prevIndex = (audioPlayer.sequence?.length ?? 1) - 1;
    }
    try {
      await seekToIndex(prevIndex).then((_) => isLoaded.value = true);
    } catch (e) {
      onError();
    }
  }

  Future setVolume(double volume) async {
    try {
      await audioPlayer.setVolume(volume);
    } catch (e) {
      _logger.e('Audio set volume to $volume failed');
      onError();
    }
  }

  Future shuffle() async {
    try {
      await updateAndResetDurationLog();
    } catch (e) {
      _logger.e('Failed to shuffle: $e');
      onError();
    }
    isAdvance = true;
    final sequence = audioPlayer.sequence;

    if (sequence == null || sequence.isEmpty) {
      return;
    }

    final random = Random();
    final shuffledSequence = List<AudioSource>.from(sequence);
    shuffledSequence.shuffle(random);

    await audioPlayer.setAudioSource(
      ConcatenatingAudioSource(children: shuffledSequence),
    );

    currentSongIndex = random.nextInt(shuffledSequence.length);

    try {
      await seekToIndex(currentSongIndex);
    } catch (e) {
      _logger.e('Failed to seek to shuffled song: $e');
    }
  }

  // Gets the current position of the song for the seekbar.
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          audioPlayer.positionStream,
          audioPlayer.bufferedPositionStream,
          audioPlayer.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  // Gets the current state of the player.
  Stream<PlayerState> get playerStateStream => audioPlayer.playerStateStream;

  SongMetadata? getCurrentSongInfo() {
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      return null;
    }
    return audioPlayer.sequence![currentSongIndex].tag;
  }

  SongMetadata getNextSongInfo() {
    if (currentSongIndex + 1 < (audioPlayer.sequence?.length ?? 0)) {
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

  List<SongMetadata> getSongOrder() {
    final sequence = audioPlayer.sequence;
    if (sequence == null || sequence.isEmpty) {
      return [];
    }
    List<SongMetadata> orderedSongs = [];
    for (int i = currentSongIndex + 1; i < sequence.length - 1; i++) {
      orderedSongs.add(sequence[i].tag);
    }
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
        stream: Stream.value(
          List<int>.from(_buffer.skip(start).take(end - start)),
        ),
      ),
    );
  }
}

class TimerService {
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  void start() {
    if (!_isRunning) {
      _startTime = DateTime.now();
      _isRunning = true;
    }
  }

  void stop() {
    if (_isRunning) {
      _elapsed += DateTime.now().difference(_startTime!);
      _startTime = null;
      _isRunning = false;
    }
  }

  void reset() {
    _startTime = null;
    _elapsed = Duration.zero;
    _isRunning = false;
  }

  Duration getElapsed() {
    if (_isRunning && _startTime != null) {
      return _elapsed + DateTime.now().difference(_startTime!);
    }
    return _elapsed;
  }
}
