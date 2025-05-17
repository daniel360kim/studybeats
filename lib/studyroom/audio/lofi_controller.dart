import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio; // Aliased just_audio
import 'package:rxdart/rxdart.dart';
import 'package:studybeats/api/audio/audio_service.dart';
import 'package:studybeats/api/audio/cloud_info/cloud_info_service.dart';
import 'package:studybeats/api/audio/objects.dart'; // Assuming LofiSongMetadata is here
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_controller.dart'; // Your abstract class
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';

class LofiAudioController
    with ChangeNotifier
    implements AbstractAudioController {
  LofiAudioController({
    required this.playlistId,
    required this.onError,
  });

  final _logger = getLogger('LofiAudioController');
  final _cloudInfoService = SongCloudInfoService();

  int playlistId;
  final VoidCallback onError;
  final just_audio.AudioPlayer audioPlayer = just_audio.AudioPlayer();
  final ValueNotifier<bool> isLoaded = ValueNotifier<bool>(false);

  TimerService songDurationTimer = TimerService();
  int currentSongIndex = 0; // This is the source of truth for the current index

  final _playlist = just_audio.ConcatenatingAudioSource(
      children: [], useLazyPreparation: false);

  @override
  bool get isPlaying => audioPlayer.playing;

  @override
  bool get isPaused =>
      !audioPlayer.playing &&
      audioPlayer.processingState != just_audio.ProcessingState.completed;

  @override
  Future<void> play() async {
    _logger.i("Lofi play() called.");
    try {
      await audioPlayer.play();
    } catch (e) {
      _logger.e('Lofi audio play failed. $e');
      onError();
    }
  }

  @override
  Future<void> pause() async {
    _logger.i("Lofi pause() called.");
    try {
      await updateAndResetDurationLog(); // Log duration before pausing
      await audioPlayer.pause();
    } catch (e) {
      _logger.e('Lofi audio pause failed. $e');
      onError();
    }
  }

  @override
  Future<void> next() async {
    _logger.i("Lofi next() called.");
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      _logger.w("Cannot go to next: playlist is empty or not loaded.");
      return;
    }
    try {
      await updateAndResetDurationLog(); // Log duration of current song
      await audioPlayer.seekToNext();
      // currentIndexStream listener will update currentSongIndex and notify
    } catch (e) {
      _logger.e('Lofi nextSong failed: $e');
      onError();
    }
  }

  @override
  Future<void> previous() async {
    _logger.i("Lofi previous() called.");
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      _logger.w("Cannot go to previous: playlist is empty or not loaded.");
      return;
    }
    try {
      await updateAndResetDurationLog(); // Log duration of current song
      await audioPlayer.seekToPrevious();
      // currentIndexStream listener will update currentSongIndex and notify
    } catch (e) {
      _logger.e('Lofi previousSong failed: $e');
      onError();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _logger.i("Lofi seek() to ${position.inMilliseconds}ms called.");
    try {
      await audioPlayer.seek(position);
    } catch (e) {
      _logger.e('Lofi audio seek to ${position.inMilliseconds} failed. $e');
      onError();
    }
  }

  @override
  Future<void> shuffle() async {
    _logger.i("Lofi shuffle() called.");
    if (audioPlayer.sequence == null || audioPlayer.sequence!.isEmpty) {
      _logger.w("Cannot shuffle: playlist is empty or not loaded.");
      return;
    }
    try {
      await updateAndResetDurationLog(); // Log duration of the current song
      // Ensure shuffle mode is ON so audioPlayer.shuffleIndices is updated
      if (!audioPlayer.shuffleModeEnabled) {
        await audioPlayer.setShuffleModeEnabled(true);
      }

      // Set isLoaded to false BEFORE shuffling and seeking.
      // This ensures the currentIndexStream listener will call notifyListeners()
      // even if the numerical index doesn't change, because !isLoaded.value will be true.
      isLoaded.value = false;
      // No notifyListeners() here for isLoaded, stream listeners will handle it.

      await audioPlayer.shuffle();
      _logger.i(
          "Playlist shuffled by audioPlayer.shuffle(). Shuffle mode is now: ${audioPlayer.shuffleModeEnabled}.");

      // After shuffling, seek to the "next" track in the new shuffled order.
      if (audioPlayer.hasNext) {
        await audioPlayer.seekToNext();
        _logger.i(
            "Sought to the next track in the shuffled sequence. currentIndexStream will update index and notify.");
      } else {
        // If no "next" (e.g., single track playlist), seek to the beginning of the current track
        // (which is now the first in the shuffled order if list was >1) or to index 0.
        await audioPlayer.seek(Duration.zero,
            index: audioPlayer.currentIndex ?? 0);
        _logger.i(
            "Sought to beginning of current/first track after shuffle (no explicit next). currentIndexStream will update index and notify.");
      }
      // The currentIndexStream listener is now the primary mechanism for updating currentSongIndex
      // and triggering notifyListeners(), which then allows PlayerWidgetState to update its UI.
    } catch (e, stacktrace) {
      _logger.e('Failed to execute shuffle operation: $e',
          stackTrace: stacktrace);
      isLoaded.value = true; // Reset on error to avoid inconsistent state
      onError();
    }
  }

  Future<void> seekToIndex(int index) async {
    _logger.i("Lofi seekToIndex($index) called.");
    if (audioPlayer.sequence == null ||
        index < 0 ||
        index >= audioPlayer.sequence!.length) {
      _logger.w("Invalid index $index or sequence not ready for seekToIndex.");
      return;
    }
    try {
      await updateAndResetDurationLog();
      // Mark as not loaded before seek, so currentIndexStream listener can pick it up
      isLoaded.value = false;
      await audioPlayer.seek(Duration.zero, index: index);
      _logger.i(
          "Seek to index $index initiated. currentIndexStream will update index and notify.");
    } catch (e) {
      _logger.e('Lofi audio seek to index $index failed: $e');
      isLoaded.value = true; // Reset on error
      onError();
    }
  }

  Future<void> initPlayer() async {
    _logger.i("Lofi initPlayer() called.");
    try {
      final service = AudioService();
      await _cloudInfoService.init();
      final playlist = await service.getPlaylistInfo(playlistId);
      final audioSources = await service.getAudioSources(playlist);

      if (audioSources.isEmpty) {
        _logger.w("No audio sources found for playlist ID: $playlistId");
        isLoaded.value = false;
        onError();
        return;
      }

      await _playlist.clear();
      await _playlist.addAll(audioSources.cast<just_audio.AudioSource>());

      await audioPlayer.setAudioSource(_playlist,
          initialIndex: 0, preload: kIsWeb ? true : false);

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      audioPlayer.playerStateStream.listen((playerState) {
        _logger.v(
            "Lofi Player State: playing=${playerState.playing}, processing=${playerState.processingState}");
        notifyListeners(); // Notify for any player state change

        if (playerState.playing) {
          songDurationTimer.start();
        } else {
          songDurationTimer.stop();
        }
      });

      audioPlayer.currentIndexStream.listen((index) async {
        if (index != null) {
          _logger.i(
              "Lofi CurrentIndexStream: received index $index. Current internal index: $currentSongIndex. isLoaded: ${isLoaded.value}");
          // Update if index changed OR if we explicitly marked as not loaded (e.g., after shuffle/seek)
          if (index != currentSongIndex || !isLoaded.value) {
            currentSongIndex = index;
            isLoaded.value = true;
            _logger.i(
                "Lofi CurrentIndexStream: Updated currentSongIndex to $currentSongIndex and isLoaded to true. Notifying listeners.");
            notifyListeners();
          }
        } else {
          _logger.i(
              "Lofi CurrentIndexStream: index is null (player likely stopped/cleared).");
          currentSongIndex = 0;
          isLoaded.value = false;
          notifyListeners();
        }
      });

      audioPlayer.positionDiscontinuityStream.listen((discontinuity) async {
        _logger.i(
            "Lofi PositionDiscontinuity: ${discontinuity.reason}, newIndex: ${audioPlayer.currentIndex}");
        if (discontinuity.reason ==
            just_audio.PositionDiscontinuityReason.autoAdvance) {
          // Log duration of the song that just finished.
          // currentSongIndex should still be the old one here before currentIndexStream updates it.
          await updateAndResetDurationLog();
          _logger.i(
              "AutoAdvanced. New track will be at index: ${audioPlayer.currentIndex}. currentIndexStream will handle state updates.");
        }
      });

      audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          _logger.e('Lofi PlaybackEventStream error: $e',
              stackTrace: stackTrace);
          onError();
        },
      );

      isLoaded.value = true; // Initial load complete
    } catch (e, stacktrace) {
      _logger.e('Error initializing Lofi audio player: $e',
          stackTrace: stacktrace);
      isLoaded.value = false;
      onError();
    }
  }

  void disposeController() async {
    _logger.i("Disposing LofiAudioController resources.");
    if (audioPlayer.playing || songDurationTimer._isRunning) {
      await updateAndResetDurationLog();
    }
    songDurationTimer.stop();
    await audioPlayer.dispose();
    isLoaded.value = false;
  }

  @override
  void dispose() {
    _logger.i("LofiAudioController (ChangeNotifier) dispose() called.");
    disposeController();
    super.dispose();
  }

  Future<void> updateAndResetDurationLog() async {
    int songIndexToLog = currentSongIndex;
    try {
      final sequence = audioPlayer.sequence;
      if (sequence == null ||
          sequence.isEmpty ||
          songIndexToLog < 0 ||
          songIndexToLog >= sequence.length) {
        _logger.w(
            'updateAndResetDurationLog: No valid song at index $songIndexToLog for duration update. Seq Len: ${sequence?.length}');
        songDurationTimer.reset();
        return;
      }

      final songMetadata = sequence[songIndexToLog].tag;
      if (songMetadata is! LofiSongMetadata) {
        _logger.w(
            'updateAndResetDurationLog: Song tag is not LofiSongMetadata at index $songIndexToLog.');
        songDurationTimer.reset();
        return;
      }
      final song = songMetadata;

      songDurationTimer.stop();
      final elapsed = songDurationTimer.getElapsed();
      songDurationTimer.reset();

      if (elapsed > Duration.zero) {
        _logger.i(
            "Logging duration for Lofi song '${song.trackName}' (index $songIndexToLog): $elapsed");
        await _cloudInfoService.updateSongDuration(playlistId, song, elapsed);
      } else {
        _logger.i(
            "No duration to log for Lofi song '${song.trackName}' (index $songIndexToLog), elapsed was zero.");
      }
    } catch (e, stacktrace) {
      _logger.e('Failed to update song duration: $e', stackTrace: stacktrace);
    }
  }

  void setSpeed(double speed) async {
    try {
      await audioPlayer.setSpeed(speed);
    } catch (e) {
      _logger.e('Lofi audio set speed to $speed failed');
      onError();
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await audioPlayer.setVolume(volume);
    } catch (e) {
      _logger.e('Lofi audio set volume to $volume failed');
      onError();
    }
  }

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          audioPlayer.positionStream,
          audioPlayer.bufferedPositionStream,
          audioPlayer.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  Stream<just_audio.PlayerState> get playerStateStream =>
      audioPlayer.playerStateStream;

  DisplayTrackInfo? getCurrentSongInfo() {
    final sequence = audioPlayer.sequence;
    if (sequence == null ||
        sequence.isEmpty ||
        currentSongIndex < 0 ||
        currentSongIndex >= sequence.length) {
      _logger.w(
          "getCurrentSongInfo: Invalid index ($currentSongIndex) or empty sequence.");
      return null;
    }
    _logger.v("getCurrentSongInfo: Returning song at index $currentSongIndex");
    final meta = sequence[currentSongIndex].tag as LofiSongMetadata;
    return DisplayTrackInfo.fromLofiSongMetadata(meta);
  }

  @override
  DisplayTrackInfo? get currentDisplayTrackInfo {
    final sequence = audioPlayer.sequence;
    if (sequence == null ||
        sequence.isEmpty ||
        currentSongIndex < 0 ||
        currentSongIndex >= sequence.length) {
      _logger.w(
          "getCurrentSongInfo: Invalid index ($currentSongIndex) or empty sequence.");
      return null;
    }
    final songMetadata = sequence[currentSongIndex].tag as LofiSongMetadata;
    return DisplayTrackInfo.fromLofiSongMetadata(
      songMetadata,
    );
  }

  DisplayTrackInfo? getNextSongInfo() {
    final sequence = audioPlayer.sequence;
    if (sequence == null || sequence.isEmpty) return null;
    final effectiveIndices = audioPlayer.effectiveIndices;
    if (effectiveIndices == null || effectiveIndices.isEmpty) return null;
    int currentEffectiveIndexPosition =
        effectiveIndices.indexOf(currentSongIndex);
    if (currentEffectiveIndexPosition == -1) {
      final meta = sequence[effectiveIndices.first].tag as LofiSongMetadata;
      return DisplayTrackInfo.fromLofiSongMetadata(meta);
    }
    int nextEffectiveIndexInList =
        (currentEffectiveIndexPosition + 1) % effectiveIndices.length;
    int actualNextIndex = effectiveIndices[nextEffectiveIndexInList];
    final meta = sequence[actualNextIndex].tag as LofiSongMetadata;
    return DisplayTrackInfo.fromLofiSongMetadata(meta);
  }

  DisplayTrackInfo? getPreviousSongInfo() {
    final sequence = audioPlayer.sequence;
    if (sequence == null || sequence.isEmpty) return null;
    final effectiveIndices = audioPlayer.effectiveIndices;
    if (effectiveIndices == null || effectiveIndices.isEmpty) return null;
    int currentEffectiveIndexPosition =
        effectiveIndices.indexOf(currentSongIndex);
    if (currentEffectiveIndexPosition == -1) {
      final meta = sequence[effectiveIndices.last].tag as LofiSongMetadata;
      return DisplayTrackInfo.fromLofiSongMetadata(meta);
    }
    int prevEffectiveIndexInList =
        (currentEffectiveIndexPosition - 1 + effectiveIndices.length) %
            effectiveIndices.length;
    int actualPrevIndex = effectiveIndices[prevEffectiveIndexInList];
    final meta = sequence[actualPrevIndex].tag as LofiSongMetadata;
    return DisplayTrackInfo.fromLofiSongMetadata(meta);
  }

  List<DisplayTrackInfo> getSongOrder() {
    final sequence = audioPlayer.sequence;
    if (sequence == null || sequence.isEmpty) return [];
    List<DisplayTrackInfo> orderedSongs = [];
    final effectiveIndices =
        audioPlayer.shuffleModeEnabled && audioPlayer.shuffleIndices != null
            ? audioPlayer.shuffleIndices!
            : List<int>.generate(sequence.length, (i) => i);
    int currentEffectiveIndexPosition =
        effectiveIndices.indexOf(currentSongIndex);
    if (currentEffectiveIndexPosition == -1) return [];
    for (int i = 1; i < effectiveIndices.length; i++) {
      int nextEffectiveIndex =
          (currentEffectiveIndexPosition + i) % effectiveIndices.length;
      orderedSongs.add(
        DisplayTrackInfo.fromLofiSongMetadata(
            sequence[effectiveIndices[nextEffectiveIndex]].tag
                as LofiSongMetadata),
      );
    }
    return orderedSongs;
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

class BufferAudioSource extends just_audio.StreamAudioSource {
  final Uint8List _buffer;
  BufferAudioSource(this._buffer) : super(tag: 'BufferAudioSource');

  @override
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    start = start ?? 0;
    end = end ?? _buffer.length;
    return just_audio.StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/wav',
      stream: Stream.value(List<int>.from(_buffer.sublist(start, end))),
    );
  }
}
