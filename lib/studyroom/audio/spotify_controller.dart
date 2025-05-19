import 'dart:async';
import 'dart:js_util' as js_util; // For JS interop in controller callbacks

import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_controller.dart';
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio/spotify_web_player_controller.dart'
    as player;

/// Player connectivity
enum PlayerConnectionStatus { none, connecting, connected, disconnected, error }

/// Thin DTO for the UI to observe
class SpotifyPlayerDisplayState extends Equatable {
  final PlayerConnectionStatus playerStatus;
  final SpotifyTrackSimple? currentTrack;
  final bool isPaused;
  final String? errorMessage;
  final String? currentlyPlayingUri;
  final bool isPlaying;

  const SpotifyPlayerDisplayState({
    required this.playerStatus,
    this.currentTrack,
    required this.isPaused,
    this.errorMessage,
    this.currentlyPlayingUri,
    required this.isPlaying,
  });

  factory SpotifyPlayerDisplayState.initial() =>
      const SpotifyPlayerDisplayState(
        playerStatus: PlayerConnectionStatus.none,
        currentTrack: null,
        isPaused: true,
        errorMessage: null,
        currentlyPlayingUri: null,
        isPlaying: false,
      );

  @override
  List<Object?> get props => [
        playerStatus,
        currentTrack,
        isPaused,
        errorMessage,
        currentlyPlayingUri,
        isPlaying
      ];
}

class SpotifyPlaybackController implements AbstractAudioController {
  final SpotifyAuthService _authService;
  final SpotifyApiService _apiService;
  final player.SpotifyWebPlayerController _playerController =
      player.SpotifyWebPlayerController();
  final _logger = getLogger('SpotifyPlaybackController');

  /// Handles exceptions, logs, sets error state, and updates UI.
  void _handleException(String userMessage, Object? error,
      [StackTrace? stack]) {
    _logger.e(userMessage, error: error, stackTrace: stack);
    _playerStatus = PlayerConnectionStatus.error;
    _playerConnectionErrorMsg = userMessage;
    if (!_errorController.isClosed) _errorController.add(userMessage);
    _update();
  }

  // ---------------------------------------------------------------------------
  //  Error broadcasting
  // ---------------------------------------------------------------------------
  final PublishSubject<String> _errorController = PublishSubject<String>();
  Stream<String> get errorStream => _errorController.stream;

  // ---------------------------------------------------------------------------
  //  Player-connection state
  // ---------------------------------------------------------------------------
  PlayerConnectionStatus _playerStatus = PlayerConnectionStatus.none;
  String? _playerConnectionErrorMsg;

  String? _currentlyPlayingUri;
  bool _isSdkPlayerPaused = true;
  SpotifyTrackSimple? _currentSpotifyTrackDetails;

  // ---------------------------------------------------------------------------
  //  Cached playlists & tracks
  // ---------------------------------------------------------------------------
  List<SpotifyPlaylistSimple>? _cachedUserPlaylists;
  final Map<String, List<SpotifyTrackSimple>> _playlistTracksCache = {};

  /// Read-only getters for UI
  List<SpotifyPlaylistSimple>? get cachedUserPlaylists => _cachedUserPlaylists;
  List<SpotifyTrackSimple>? getCachedPlaylistTracks(String playlistId) =>
      _playlistTracksCache[playlistId];

  // ---------------------------------------------------------------------------
  //  Streams for outsiders
  // ---------------------------------------------------------------------------
  final StreamController<PositionData> _positionStreamController =
      StreamController<PositionData>.broadcast();
  final BehaviorSubject<bool> _isPlayingController =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _isBufferingController =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<SpotifyPlayerDisplayState> _displayStateController =
      BehaviorSubject<SpotifyPlayerDisplayState>.seeded(
          SpotifyPlayerDisplayState.initial());

  /// Observable stream of player/UI state for widgets such as AudioSourceSwitcher.
  Stream<SpotifyPlayerDisplayState> get displayStateStream =>
      _displayStateController.stream;

  // ---------------------------------------------------------------------------
  //  Misc
  // ---------------------------------------------------------------------------
  List<SpotifyTrackSimple> _currentContextTracks = [];

  /// Index of the currently playing item within [_currentContextTracks].
  /// -1 means “no track selected yet”.
  int _currentIndex = -1;

  // ---------------------------------------------------------------------------
  //  Progress timer (keeps seek bar moving & detects end-of-track)
  // ---------------------------------------------------------------------------
  Timer? _progressTimer;
  int _lastPositionMs = 0;
  int _currentTrackDurationMs = 0;
  DateTime? _lastPositionTimestamp;
  bool _autoNextTriggered = false;

  SpotifyPlaybackController({
    required SpotifyAuthService authService,
    required SpotifyApiService apiService,
  })  : _authService = authService,
        _apiService = apiService {
    _logger.i("SpotifyPlaybackController initialized.");
  }

  // ===========================================================================
  //  Library helpers
  // ===========================================================================

  bool _isAuthed() =>
      _authService.isAuthenticated && _authService.accessToken != null;

  Future<List<SpotifyPlaylistSimple>?> fetchUserPlaylists(
      {bool forceRefresh = false}) async {
    if (_cachedUserPlaylists != null && !forceRefresh) {
      return _cachedUserPlaylists;
    }
    if (!_isAuthed()) return null;

    try {
      final data = await _apiService.getUserPlaylists(_authService.accessToken!,
          limit: 50);
      final items = (data?['items'] ?? []) as List<dynamic>;
      _cachedUserPlaylists =
          items.map((e) => _parsePlaylist(e)).toList(growable: false);
      _logger.i("Cached ${_cachedUserPlaylists!.length} playlists.");
      return _cachedUserPlaylists;
    } catch (e, st) {
      _logger.e('fetchUserPlaylists error', error: e, stackTrace: st);
      return null;
    }
  }

  Future<List<SpotifyTrackSimple>?> fetchPlaylistTracks(
    String playlistId, {
    bool forceRefresh = false,
  }) async {
    if (_playlistTracksCache.containsKey(playlistId) && !forceRefresh) {
      return _playlistTracksCache[playlistId];
    }
    if (!_isAuthed()) return null;

    try {
      final data = await _apiService.getPlaylistTracks(
        _authService.accessToken!,
        playlistId,
        limit: 100,
      );
      final items = (data?['items'] ?? []) as List<dynamic>;
      final tracks = items
          .map((e) => _parseTrack(e))
          .whereType<SpotifyTrackSimple>()
          .toList(growable: false);
      _playlistTracksCache[playlistId] = tracks;
      _logger.i("Cached ${tracks.length} tracks for playlist $playlistId.");
      return tracks;
    } catch (e, st) {
      _logger.e('fetchPlaylistTracks error', error: e, stackTrace: st);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  //  Local parsers
  // ---------------------------------------------------------------------------
  SpotifyPlaylistSimple _parsePlaylist(Map<String, dynamic> item) {
    return SpotifyPlaylistSimple(
      id: item['id'] ?? '',
      name: item['name'] ?? 'Unknown Playlist',
      imageUrl: (item['images'] as List?)?.isNotEmpty == true
          ? item['images'][0]['url']
          : null,
      totalTracks: item['tracks']?['total'] ?? 0,
    );
  }

  SpotifyTrackSimple? _parseTrack(Map<String, dynamic> item) {
    final track = item['track'];
    if (track == null ||
        track['id'] == null ||
        track['uri'] == null ||
        track['is_local'] == true) {
      return null;
    }
    final artists = (track['artists'] as List<dynamic>?)
            ?.map((a) => a['name'] as String)
            .join(', ') ??
        'Unknown Artist';
    final imageUrl = (track['album']?['images'] as List?)?.isNotEmpty == true
        ? track['album']['images'][0]['url']
        : null;
    return SpotifyTrackSimple(
      id: track['id'],
      name: track['name'] ?? 'Unknown Track',
      artists: artists,
      albumName: track['album']?['name'],
      albumImageUrl: imageUrl,
      uri: track['uri'],
      durationMs: track['duration_ms'] ?? 0,
    );
  }

  // ===========================================================================
  //  Player bootstrap / callbacks
  // ===========================================================================

  @override
  Future<void> init() async => initializePlayer();

  Future<void> initializePlayer() async {
    try {
      if (!_isAuthed()) {
        _playerStatus = PlayerConnectionStatus.error;
        _playerConnectionErrorMsg = "Authentication required.";
        _update();
        return;
      }

      if (_playerController.isPlayerInitializedAndReady ||
          _playerStatus == PlayerConnectionStatus.connecting) {
        if (_playerController.isPlayerInitializedAndReady &&
            _playerStatus != PlayerConnectionStatus.connected) {
          _playerStatus = PlayerConnectionStatus.connected;
          _update();
        }
        return;
      }

      _playerStatus = PlayerConnectionStatus.connecting;
      _update();

      _setupPlayerControllerCallbacks();
      _playerController.init(
          _authService.accessToken!, "StudyBeats Web Player (Provider)");
    } catch (e, st) {
      _handleException("Failed to initialize Spotify player.", e, st);
    }
  }

  void _setupPlayerControllerCallbacks() {
    _playerController.onPlayerReady = (deviceId) {
      _playerStatus = PlayerConnectionStatus.connected;
      _playerConnectionErrorMsg = null;
      _update();
    };

    _playerController.onPlayerStateChanged = (dynamic jsState) {
      if (jsState == null) {
        _currentlyPlayingUri = null;
        _isSdkPlayerPaused = true;
        _currentSpotifyTrackDetails = null;
        _positionStreamController
            .add(PositionData(Duration.zero, Duration.zero, Duration.zero));
        _stopProgressTimer();
        _update();
        return;
      }

      final trackWindow = js_util.getProperty(jsState, 'track_window');
      final currentTrackJs = js_util.getProperty(trackWindow, 'current_track');
      final uri = js_util.getProperty(currentTrackJs, 'uri');
      final durationMs =
          js_util.getProperty(currentTrackJs, 'duration_ms') ?? 0;
      final paused = js_util.getProperty(jsState, 'paused');
      final positionMs = js_util.getProperty(jsState, 'position') ?? 0;

      _currentlyPlayingUri = uri;
      _isSdkPlayerPaused = paused;
      // If the player just paused naturally at (or extremely near) the end
      // of the track, trigger auto‑next as a fallback. This handles cases
      // where the final SDK progress callback arrives *after* the pause,
      // so our periodic timer never fires the wrap‑around.
      if (paused &&
          !_autoNextTriggered &&
          _currentTrackDurationMs > 0 &&
          positionMs >= _currentTrackDurationMs - 500 &&
          _currentContextTracks.isNotEmpty) {
        _autoNextTriggered = true;
        next();
      }
      _positionStreamController.add(PositionData(
          Duration(milliseconds: positionMs),
          Duration.zero,
          Duration(milliseconds: durationMs)));

      _currentTrackDurationMs = durationMs;

      if (!paused) {
        _lastPositionMs = positionMs;
        _lastPositionTimestamp = DateTime.now();
        _autoNextTriggered = false;
        _startProgressTimer();
      } else {
        _stopProgressTimer();
        _autoNextTriggered = false;
      }

      _updateCurrentSpotifyTrackDetails(uri, currentTrackJs);
      _update();
    };

    _playerController.onPlayerError = (msg) {
      _playerStatus = PlayerConnectionStatus.error;
      _playerConnectionErrorMsg = msg ?? "Unknown player error";
      _update();
    };

    _playerController.onPlayerNotReady = (deviceId) {
      _playerStatus = PlayerConnectionStatus.disconnected;
      _playerConnectionErrorMsg = "Player $deviceId went offline.";
      _currentlyPlayingUri = null;
      _isSdkPlayerPaused = true;
      _currentSpotifyTrackDetails = null;
      _stopProgressTimer();
      _update();
    };
  }

  // ---------------------------------------------------------------------------
  //  Progress timer helpers
  // ---------------------------------------------------------------------------
  void _startProgressTimer() {
    if (_progressTimer != null && _progressTimer!.isActive) return;
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_playerStatus != PlayerConnectionStatus.connected ||
          _isSdkPlayerPaused) {
        _stopProgressTimer();
        return;
      }
      if (_currentTrackDurationMs <= 0) return;

      final now = DateTime.now();
      final elapsed =
          now.difference(_lastPositionTimestamp ?? now).inMilliseconds;
      final newPos =
          (_lastPositionMs + elapsed).clamp(0, _currentTrackDurationMs).toInt();

      _positionStreamController.add(PositionData(Duration(milliseconds: newPos),
          Duration.zero, Duration(milliseconds: _currentTrackDurationMs)));

      // Auto-advance when within 500 ms of track end
      if (!_autoNextTriggered &&
          newPos >= _currentTrackDurationMs - 500 &&
          _currentContextTracks.isNotEmpty) {
        _autoNextTriggered = true;
        next(); // wrap handled inside next()
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ---------------------------------------------------------------------------
  //  Private helpers
  // ---------------------------------------------------------------------------
  void _updatePlayerStateStreams() {
    final playing = _playerStatus == PlayerConnectionStatus.connected &&
        !_isSdkPlayerPaused;
    if (_isPlayingController.value != playing) {
      _isPlayingController.add(playing);
    }

    final buffering = _playerStatus == PlayerConnectionStatus.connecting;
    if (_isBufferingController.value != buffering) {
      _isBufferingController.add(buffering);
    }
  }

  void _update() {
    _updatePlayerStateStreams();
    final newState = SpotifyPlayerDisplayState(
      playerStatus: _playerStatus,
      currentTrack: _currentSpotifyTrackDetails,
      isPaused: isPaused,
      errorMessage: _playerConnectionErrorMsg,
      currentlyPlayingUri: _currentlyPlayingUri,
      isPlaying: isPlaying,
    );
    if (!_displayStateController.isClosed &&
        _displayStateController.value != newState) {
      _displayStateController.add(newState);
    }
  }

  Future<void> _updateCurrentSpotifyTrackDetails(
      String? trackUri, dynamic currentTrackJs) async {
    if (trackUri == null) {
      _currentSpotifyTrackDetails = null;
      return;
    }

    // Try queue cache first
    try {
      _currentSpotifyTrackDetails =
          _currentContextTracks.firstWhere((t) => t.uri == trackUri);
    } catch (_) {
      _currentSpotifyTrackDetails = null;
    }

    // Fallback: parse JS object if cache miss
    if (_currentSpotifyTrackDetails == null && currentTrackJs != null) {
      try {
        final id = js_util.getProperty(currentTrackJs, 'id') ??
            trackUri.split(':').last;
        final name = js_util.getProperty(currentTrackJs, 'name') ?? 'Unknown';
        final artistsJs = js_util.getProperty(currentTrackJs, 'artists');
        final artists = (artistsJs as List<dynamic>?)
                ?.map((a) => js_util.getProperty(a, 'name') as String)
                .join(', ') ??
            'Unknown Artist';
        final albumJs = js_util.getProperty(currentTrackJs, 'album');
        String? albumName;
        String? albumImageUrl;
        if (albumJs != null) {
          albumName = js_util.getProperty(albumJs, 'name');
          final images = js_util.getProperty(albumJs, 'images');
          if (images is List && images.isNotEmpty) {
            albumImageUrl = js_util.getProperty(images[0], 'url');
          }
        }
        final durationMs =
            js_util.getProperty(currentTrackJs, 'duration_ms') ?? 0;

        _currentSpotifyTrackDetails = SpotifyTrackSimple(
          id: id,
          name: name,
          artists: artists,
          albumName: albumName,
          albumImageUrl: albumImageUrl,
          uri: trackUri,
          durationMs: durationMs,
        );
      } catch (e) {
        _logger.e("Error parsing JS track details: $e");
      }
    }
  }

  // ===========================================================================
  //  Queue management
  // ===========================================================================
  /// Replace the current play queue without starting playback.
  void setQueue(List<SpotifyTrackSimple> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) return;
    _currentContextTracks = List.from(tracks, growable: false);
    _currentIndex = startIndex.clamp(0, _currentContextTracks.length - 1);
    _logger.i(
        "Queue set with ${_currentContextTracks.length} tracks (cursor=$_currentIndex).");
  }

  // ===========================================================================
  //  Public playback API
  // ===========================================================================
  Future<void> playTrack(
    String trackUri, {
    List<SpotifyTrackSimple>? contextTracks,
    bool updateQueue = true,
  }) async {
    try {
      if (updateQueue && contextTracks != null && contextTracks.isNotEmpty) {
        // (Re)build queue and set cursor to the requested track.
        final idx = contextTracks.indexWhere((t) => t.uri == trackUri);
        setQueue(contextTracks, startIndex: idx >= 0 ? idx : 0);
      } else if (_currentContextTracks.isNotEmpty) {
        // Keep existing queue; adjust cursor.
        final idx = _currentContextTracks.indexWhere((t) => t.uri == trackUri);
        if (idx >= 0) _currentIndex = idx;
      }
      await _updateCurrentSpotifyTrackDetails(trackUri, null);
      _autoNextTriggered = false; // reset for new track

      if (!_playerController.isPlayerInitializedAndReady) {
        await initializePlayer();
        if (!_playerController.isPlayerInitializedAndReady) return;
      }

      final deviceId = _playerController.getCurrentSdkDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        _handleException("No active player device.", null);
        return;
      }

      final result = await _apiService.playItems(
        _authService.accessToken!,
        deviceId: deviceId,
        trackUris: [trackUri],
      );

      if (result != 'SUCCESS') {
        _handleException("Playback failed: $result", null);
      }
    } catch (e, st) {
      _handleException("An error occurred during playback.", e, st);
    }
  }

  void togglePlayPause() {
    try {
      if (_playerController.isPlayerInitializedAndReady) {
        _playerController.togglePlay();
      }
    } catch (e, st) {
      _handleException("Play/Pause failed.", e, st);
    }
  }

  // ===========================================================================
  //  AbstractAudioController implementation
  // ===========================================================================
  @override
  bool get isPlaying =>
      _playerStatus == PlayerConnectionStatus.connected && !_isSdkPlayerPaused;

  @override
  bool get isPaused =>
      _playerStatus == PlayerConnectionStatus.connected && _isSdkPlayerPaused;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<bool> get isBufferingStream => _isBufferingController.stream;

  @override
  Stream<PositionData> get positionDataStream =>
      _positionStreamController.stream;

  @override
  DisplayTrackInfo? get currentDisplayTrackInfo =>
      _currentSpotifyTrackDetails == null
          ? null
          : DisplayTrackInfo.fromSpotifyTrack(_currentSpotifyTrackDetails!);

  @override
  Future<void> play() async => togglePlayPause();

  @override
  Future<void> pause() async => togglePlayPause();

  @override
  Future<void> stop() async {
    if (_playerController.isPlayerInitializedAndReady && isPlaying) {
      _playerController.togglePlay();
    }
  }

  @override
  Future<void> next() async {
    try {
      if (_currentContextTracks.isEmpty) return;
      _currentIndex = (_currentIndex + 1) % _currentContextTracks.length;
      await playTrack(
        _currentContextTracks[_currentIndex].uri,
        updateQueue: false,
      );
    } catch (e, st) {
      _handleException("Error advancing to next track.", e, st);
    }
  }

  @override
  Future<void> previous() async {
    try {
      if (_currentContextTracks.isEmpty) return;
      _currentIndex =
          (_currentIndex - 1 + _currentContextTracks.length) % _currentContextTracks.length;
      await playTrack(
        _currentContextTracks[_currentIndex].uri,
        updateQueue: false,
      );
    } catch (e, st) {
      _handleException("Error going back to previous track.", e, st);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      if (_playerController.isPlayerInitializedAndReady &&
          player.spotifyPlayerInstance != null) {
        _lastPositionMs = position.inMilliseconds;
        _lastPositionTimestamp = DateTime.now();
        _autoNextTriggered = false;
        js_util.callMethod(
            player.spotifyPlayerInstance!, 'seek', [position.inMilliseconds]);
      }
    } catch (e, st) {
      _handleException("Seek failed.", e, st);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      if (_playerController.isPlayerInitializedAndReady &&
          player.spotifyPlayerInstance != null) {
        js_util.callMethod(
            player.spotifyPlayerInstance!, 'setVolume', [volume.clamp(0.0, 1.0)]);
      }
    } catch (e, st) {
      _handleException("Setting volume failed.", e, st);
    }
  }

  @override
  Future<void> shuffle() async {
    try {
      // existing shuffle logic here
    } catch (e, st) {
      _handleException("Error toggling shuffle.", e, st);
    }
  }

  // ---------------------------------------------------------------------------
  //  Disposal
  // ---------------------------------------------------------------------------
  Future<void> disposePlayer() async {
    if (_playerController.isPlayerInitializedAndReady) {
      _playerController.dispose();
    }
    _playerStatus = PlayerConnectionStatus.none;
    _currentlyPlayingUri = null;
    _currentSpotifyTrackDetails = null;
    _isSdkPlayerPaused = true;
    _currentContextTracks = [];
    _stopProgressTimer();
    _update();
  }

  @override
  void dispose() {
    _errorController.close();
    _playerController.dispose();
    _stopProgressTimer();
    _positionStreamController.close();
    _isPlayingController.close();
    _isBufferingController.close();
    _displayStateController.close();
  }
}
