import 'dart:async';
import 'dart:js_util' as js_util; // For JS interop in controller callbacks

import 'package:flutter/foundation.dart'; // Required for ChangeNotifier
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_controller.dart';
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart'; // For PositionData
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
// Import the file that defines spotifyPlayerInstance and other JS interop functions
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_web_player_controller.dart';

// This enum can be defined here or in a shared location if AudioSourceSwitcher also uses it directly.
enum PlayerConnectionStatus { none, connecting, connected, disconnected, error }

class SpotifyPlaybackProvider
    with ChangeNotifier
    implements AbstractAudioController {
  final SpotifyAuthService _authService;
  final SpotifyApiService _apiService;
  final SpotifyWebPlayerController _playerController =
      SpotifyWebPlayerController(); // Dart wrapper
  final _logger = getLogger('SpotifyPlaybackProvider');

  PlayerConnectionStatus _playerStatus = PlayerConnectionStatus.none;
  PlayerConnectionStatus get playerStatus => _playerStatus;

  String? _playerConnectionErrorMsg;
  String? get playerConnectionErrorMsg => _playerConnectionErrorMsg;

  String? _currentlyPlayingUri;
  String? get currentlyPlayingUri => _currentlyPlayingUri;

  bool _isSdkPlayerPaused = true;
  // bool get isSdkPlayerPaused => _isSdkPlayerPaused; // Keep this if direct access is still needed

  SpotifyTrackSimple? _currentSpotifyTrackDetails;
  SpotifyTrackSimple? get currentSpotifyTrackDetails =>
      _currentSpotifyTrackDetails;

  final StreamController<PositionData> _spotifyPositionDataStreamController =
      StreamController<PositionData>.broadcast();
  Stream<PositionData> get spotifyPositionDataStream =>
      _spotifyPositionDataStreamController.stream;

  List<SpotifyTrackSimple> _currentContextTracks = [];

  SpotifyPlaybackProvider(
      {required SpotifyAuthService authService,
      required SpotifyApiService apiService})
      : _authService = authService,
        _apiService = apiService {
    _logger.i("SpotifyPlaybackProvider initialized.");
    // Callbacks are set up when _playerController.init is called by initializePlayer()
  }

  void _updateAndNotify() {
    notifyListeners();
  }

  // This method is called by this provider's initializePlayer method
  void _setupPlayerControllerCallbacks() {
    _playerController.onPlayerReady = (deviceId) {
      _logger.i("SDK Player Ready (Provider CB). Device ID: $deviceId");
      _playerStatus = PlayerConnectionStatus.connected;
      _playerConnectionErrorMsg = null;
      _updateAndNotify();
    };

    _playerController.onPlayerStateChanged = (dynamic jsPlayerState) {
      if (jsPlayerState == null) {
        _logger.i("SDK State (Provider CB): Player state is null.");
        if (_currentlyPlayingUri != null || !_isSdkPlayerPaused) {
          _currentlyPlayingUri = null;
          _isSdkPlayerPaused = true;
          _currentSpotifyTrackDetails = null;
          _spotifyPositionDataStreamController
              .add(PositionData(Duration.zero, Duration.zero, Duration.zero));
        }
        if (_playerStatus == PlayerConnectionStatus.connected) {
          _playerStatus = PlayerConnectionStatus.disconnected;
          _playerConnectionErrorMsg =
              "Player state became null (possibly disconnected).";
        }
        _updateAndNotify();
        return;
      }
      try {
        final trackWindow = js_util.getProperty(jsPlayerState, 'track_window');
        final currentTrackJs =
            js_util.getProperty(trackWindow, 'current_track');
        String? sdkTrackUri;
        int sdkDurationMs = 0;
        String? newTrackName;

        if (currentTrackJs != null) {
          sdkTrackUri = js_util.getProperty(currentTrackJs, 'uri');
          sdkDurationMs =
              js_util.getProperty(currentTrackJs, 'duration_ms') ?? 0;
          newTrackName = js_util.getProperty(currentTrackJs, 'name');
          if (_currentlyPlayingUri != sdkTrackUri ||
              _currentSpotifyTrackDetails == null ||
              _currentSpotifyTrackDetails!.uri != sdkTrackUri) {
            _updateCurrentSpotifyTrackDetails(sdkTrackUri, currentTrackJs);
          }
        } else {
          _currentSpotifyTrackDetails = null;
        }

        final bool sdkIsPaused = js_util.getProperty(jsPlayerState, 'paused');
        final int sdkPositionMs =
            js_util.getProperty(jsPlayerState, 'position') ?? 0;
        _spotifyPositionDataStreamController.add(PositionData(
            Duration(milliseconds: sdkPositionMs),
            Duration.zero,
            Duration(milliseconds: sdkDurationMs)));

        bool changed = false;
        if (_currentlyPlayingUri != sdkTrackUri) {
          _currentlyPlayingUri = sdkTrackUri;
          changed = true;
        }
        if (_isSdkPlayerPaused != sdkIsPaused) {
          _isSdkPlayerPaused = sdkIsPaused;
          changed = true;
        }
        if (_playerStatus != PlayerConnectionStatus.connected &&
            sdkTrackUri != null) {
          _playerStatus = PlayerConnectionStatus.connected;
          _playerConnectionErrorMsg = null;
          changed = true;
        }
        if (changed) {
          _logger.d(
              "SDK State Updated (Provider CB): URI: $sdkTrackUri, Name: $newTrackName, Paused: $sdkIsPaused, Pos: $sdkPositionMs");
          _updateAndNotify();
        }
      } catch (e, stacktrace) {
        _logger.e("Error parsing player state in provider CB: $e",
            stackTrace: stacktrace);
      }
    };

    _playerController.onPlayerError = (errorMsg) {
      _logger.e("SDK Player ERROR (Provider CB): $errorMsg");
      _playerStatus = PlayerConnectionStatus.error;
      _playerConnectionErrorMsg = errorMsg ?? "Unknown player error";
      _updateAndNotify();
    };

    _playerController.onPlayerNotReady = (deviceId) {
      _logger.w("SDK Player NOT READY (Provider CB) for device: $deviceId.");
      if (_playerStatus == PlayerConnectionStatus.connected ||
          _playerStatus == PlayerConnectionStatus.connecting) {
        _playerStatus = PlayerConnectionStatus.disconnected;
      }
      _playerConnectionErrorMsg = "Player $deviceId went offline.";
      _isSdkPlayerPaused = true;
      _currentlyPlayingUri = null;
      _currentSpotifyTrackDetails = null;
      _spotifyPositionDataStreamController
          .add(PositionData(Duration.zero, Duration.zero, Duration.zero));
      _updateAndNotify();
    };
  }
  @override 
  DisplayTrackInfo? get currentDisplayTrackInfo {
    return null;
  }

  @override
  Stream<PositionData> get positionDataStream =>
      _spotifyPositionDataStreamController.stream;

  Future<void> _updateCurrentSpotifyTrackDetails(
      String? trackUri, dynamic currentTrackJs) async {
    // ... (implementation remains the same)
    if (trackUri == null) {
      _currentSpotifyTrackDetails = null;
      return;
    }
    try {
      _currentSpotifyTrackDetails =
          _currentContextTracks.firstWhere((t) => t.uri == trackUri);
    } catch (e) {
      // Catch StateError if not found
      _currentSpotifyTrackDetails = null;
    }

    if (_currentSpotifyTrackDetails == null && currentTrackJs != null) {
      try {
        String id = js_util.getProperty(currentTrackJs, 'id') ??
            trackUri.split(':').last;
        String name =
            js_util.getProperty(currentTrackJs, 'name') ?? 'Unknown Track';
        List<dynamic>? artistsJs =
            js_util.getProperty(currentTrackJs, 'artists');
        String artists = artistsJs
                ?.map((a) => js_util.getProperty(a, 'name') as String)
                .join(', ') ??
            'Unknown Artist';
        dynamic albumJs = js_util.getProperty(currentTrackJs, 'album');
        String? albumName;
        String? albumImageUrl;
        if (albumJs != null) {
          albumName = js_util.getProperty(albumJs, 'name');
          List<dynamic>? imagesJs = js_util.getProperty(albumJs, 'images');
          if (imagesJs != null && imagesJs.isNotEmpty) {
            albumImageUrl = js_util.getProperty(imagesJs[0], 'url');
          }
        }
        int durationMs =
            js_util.getProperty(currentTrackJs, 'duration_ms') ?? 0;

        _currentSpotifyTrackDetails = SpotifyTrackSimple(
            id: id,
            name: name,
            artists: artists,
            albumName: albumName,
            albumImageUrl: albumImageUrl,
            uri: trackUri,
            durationMs: durationMs);
        _logger.i("Updated track details from JS Player State: ${name}");
      } catch (e) {
        _logger.e("Error parsing track details from JS Player State: $e");
        _currentSpotifyTrackDetails = SpotifyTrackSimple(
            id: trackUri.split(':').last,
            name: "Loading info...",
            artists: "...",
            uri: trackUri,
            durationMs: 0);
      }
    } else if (_currentSpotifyTrackDetails == null) {
      _logger.w(
          "Details for playing Spotify URI $trackUri not found in cache and no JS object provided. Creating placeholder.");
      _currentSpotifyTrackDetails = SpotifyTrackSimple(
          id: trackUri.split(':').last,
          name: "Track Information",
          artists: "Loading...",
          uri: trackUri,
          durationMs: 0);
    }
  }

  Future<void> initializePlayer() async {
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _logger.w("Cannot initialize player: User not authenticated.");
      _playerStatus = PlayerConnectionStatus.error;
      _playerConnectionErrorMsg = "Authentication required.";
      _updateAndNotify();
      return;
    }
    if (_playerController.isPlayerInitializedAndReady ||
        _playerStatus == PlayerConnectionStatus.connecting) {
      _logger.i("Player already initialized or connecting.");
      if (_playerController.isPlayerInitializedAndReady &&
          _playerStatus != PlayerConnectionStatus.connected) {
        // Correct status if controller is ready but provider status isn't
        _playerStatus = PlayerConnectionStatus.connected;
        _updateAndNotify();
      }
      return;
    }
    _logger.i("Initializing Spotify Web Player via Provider...");
    _playerStatus = PlayerConnectionStatus.connecting;
    _playerConnectionErrorMsg = null;
    _updateAndNotify();

    // Setup the callbacks that the _playerController's init method will use.
    // These callbacks will update this provider's state.
    _setupPlayerControllerCallbacks();

    // Now call init on the controller. It will use the callbacks we just set on it.
    _playerController.init(
        _authService.accessToken!, "StudyBeats Web Player (Provider)");
  }

  Future<void> playTrack(String trackUri,
      {List<SpotifyTrackSimple>? contextTracks}) async {
    // ... (implementation remains the same)
    _logger.i("Provider: playTrack called for URI: $trackUri");
    if (contextTracks != null) {
      _currentContextTracks = List.from(contextTracks);
    } else {
      bool foundInCache = false;
      for (var cachedList in _playlistTracksCache.values) {
        var trackDetail = cachedList.firstWhere(
          (t) => t.uri == trackUri,
          orElse: () => SpotifyTrackSimple(
            id: trackUri.split(':').last,
            name: "Unknown Track",
            artists: "Unknown Artist",
            uri: trackUri,
            durationMs: 0,
          ),
        );
        if (trackDetail != null) {
          _currentContextTracks = [trackDetail];
          foundInCache = true;
          break;
        }
      }
      if (!foundInCache) _currentContextTracks = [];
    }
    await _updateCurrentSpotifyTrackDetails(trackUri, null);

    if (!_playerController.isPlayerInitializedAndReady) {
      _logger
          .w("Player not ready for playTrack. Attempting to initialize first.");
      await initializePlayer();
      if (!_playerController.isPlayerInitializedAndReady) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    if (!_playerController.isPlayerInitializedAndReady ||
        _authService.accessToken == null) {
      _logger.e("Cannot play track: Player not ready or no access token.");
      _playerStatus = PlayerConnectionStatus.error;
      _playerConnectionErrorMsg = "Player not ready or authentication error.";
      _updateAndNotify();
      return;
    }

    final sdkDeviceId = _playerController.getCurrentSdkDeviceId();
    if (sdkDeviceId != null && sdkDeviceId.isNotEmpty) {
      _logger.i("Playing track via SDK on device: $sdkDeviceId");
      try {
        final result = await _apiService.playItems(_authService.accessToken!,
            deviceId: sdkDeviceId, trackUris: [trackUri]);
        if (result == 'SUCCESS') {
          _logger.i("Playback command successful for $trackUri");
        } else {
          _logger.w("Playback command failed for $trackUri: $result");
          _playerStatus = PlayerConnectionStatus.error;
          _playerConnectionErrorMsg = "Playback failed: $result";
          _updateAndNotify();
        }
      } catch (e) {
        _logger.e("Exception during playTrack: $e");
        _playerStatus = PlayerConnectionStatus.error;
        _playerConnectionErrorMsg = "Error starting playback.";
        _updateAndNotify();
      }
    } else {
      _logger.w("No SDK device ID available to play track.");
      _playerStatus = PlayerConnectionStatus.error;
      _playerConnectionErrorMsg = "No active player device.";
      _updateAndNotify();
    }
  }

  // --- AbstractAudioController Implementation ---
  @override
  bool get isPlaying =>
      _playerStatus == PlayerConnectionStatus.connected && !_isSdkPlayerPaused;

  @override
  bool get isPaused =>
      _playerStatus == PlayerConnectionStatus.connected && _isSdkPlayerPaused;

  @override
  Future<void> play() async {
    _logger.i(
        "Provider: play() called (from AbstractAudioController). Is paused: $_isSdkPlayerPaused, URI: $_currentlyPlayingUri");
    if (_playerController.isPlayerInitializedAndReady) {
      if (_isSdkPlayerPaused && _currentlyPlayingUri != null) {
        // If paused and there's a track, resume
        _playerController.togglePlay(); // This is playerTogglePlay() from JS
      } else if (_currentlyPlayingUri == null) {
        // If no current URI, this play might mean "play something default" or "resume last known"
        // This logic might need to be more sophisticated depending on desired behavior.
        // For now, if there's no URI, we can't just call togglePlay.
        // Perhaps play the first track from _currentContextTracks if available?
        if (_currentContextTracks.isNotEmpty) {
          await playTrack(_currentContextTracks.first.uri,
              contextTracks: _currentContextTracks);
        } else {
          _logger.w("Play called but no current URI and no context tracks.");
        }
      }
      // If already playing, do nothing.
    } else {
      _logger.w("Cannot play: Player not ready.");
      if (!_authService.isAuthenticated) {
        _playerStatus = PlayerConnectionStatus.error;
        _playerConnectionErrorMsg = "Please login to Spotify.";
        _updateAndNotify();
      } else {
        await initializePlayer();
      }
    }
  }

  @override
  Future<void> pause() async {
    _logger.i(
        "Provider: pause() called (from AbstractAudioController). Is playing: $isPlaying");
    if (_playerController.isPlayerInitializedAndReady && isPlaying) {
      // Only pause if actually playing
      _playerController.togglePlay(); // This is playerTogglePlay() from JS
    } else {
      _logger.w("Cannot pause: Player not ready or already paused.");
    }
  }

  // This method maps to the existing togglePlayPause for simplicity if called from UI
  // The abstract play() and pause() are more explicit.
  void togglePlayPause() {
    _logger.i(
        "Provider: togglePlayPause called. Is player ready: ${_playerController.isPlayerInitializedAndReady}");
    if (_playerController.isPlayerInitializedAndReady) {
      playerTogglePlay(); // Call the global JS interop function
    } else {
      _logger.w("Cannot toggle play/pause: Player not ready.");
      if (!_authService.isAuthenticated) {
        _playerStatus = PlayerConnectionStatus.error;
        _playerConnectionErrorMsg = "Please login to Spotify.";
        _updateAndNotify();
      } else {
        initializePlayer();
      }
    }
  }

  @override
  Future<void> next() async {
    _logger.i("Provider: next() called (from AbstractAudioController).");
    if (_playerController.isPlayerInitializedAndReady) {
      playerNextTrack(); // Call the global JS interop function
    }
  }

  @override
  Future<void> previous() async {
    _logger.i("Provider: previous() called (from AbstractAudioController).");
    if (_playerController.isPlayerInitializedAndReady) {
      playerPreviousTrack(); // Call the global JS interop function
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _logger.i(
        "Provider: seek called to ${position.inMilliseconds}ms (from AbstractAudioController)");
    if (_playerController.isPlayerInitializedAndReady &&
        spotifyPlayerInstance != null) {
      js_util.callMethod(
          spotifyPlayerInstance!, 'seek', [position.inMilliseconds]);
    } else {
      _logger.w("Seek failed: Player not ready or instance is null.");
    }
  }

  // This is a new public method for volume, not from AbstractAudioController
  // If AbstractAudioController needs volume, add it there.
  @override 
  Future<void> setVolume(double volume) async {
    _logger.i("Provider: setVolume called to $volume");
    if (_playerController.isPlayerInitializedAndReady &&
        spotifyPlayerInstance != null) {
      js_util.callMethod(
          spotifyPlayerInstance!, 'setVolume', [volume.clamp(0.0, 1.0)]);
    } else {
      _logger.w("SetVolume failed: Player not ready or instance is null.");
    }
  }

  @override
  Future<void> shuffle() async {
    _logger.i("Provider: shuffle() called (from AbstractAudioController).");
    // Spotify SDK shuffle is typically a mode set via API, not a simple "play shuffled next"
    // This requires calling the Spotify API to toggle shuffle mode for the current device.
    if (_playerController.isPlayerInitializedAndReady &&
        _authService.isAuthenticated &&
        _authService.accessToken != null) {
      final deviceId = _playerController.getCurrentSdkDeviceId();
      if (deviceId != null) {
        try {
          // First, get current player state to find out current shuffle state
          final playerStateResponse = await js_util.promiseToFuture(js_util
              .callMethod(spotifyPlayerInstance!, 'getCurrentState', []));
          if (playerStateResponse != null) {
            bool currentShuffleState =
                js_util.getProperty(playerStateResponse, 'shuffle') ?? false;
            _logger
                .i("Current shuffle state: $currentShuffleState. Toggling...");
            // Call API to toggle shuffle
            // Note: The http.put method for shuffle is not in your SpotifyApiService,
            // you'd need to add it or use a generic request method.
            // Example: await _apiService.setShuffle(!currentShuffleState, _authService.accessToken!, deviceId);
            _logger.w(
                "Shuffle API call not fully implemented in provider. Needs API service method.");
            // For now, just log and notify. UI won't reflect actual shuffle state from SDK without API call.
            notifyListeners(); // If you had a shuffle state variable
          } else {
            _logger.w("Could not get current player state to toggle shuffle.");
          }
        } catch (e) {
          _logger.e("Error toggling shuffle: $e");
        }
      } else {
        _logger.w("Cannot toggle shuffle: No device ID.");
      }
    } else {
      _logger
          .w("Cannot toggle shuffle: Player not ready or not authenticated.");
    }
  }

  void disposePlayer() {
    _logger.i("Provider: disposePlayer called.");
    if (_playerController.isPlayerInitializedAndReady) {
      _playerController
          .dispose(); // This calls the global disconnectSpotifyPlayer()
    }
    _playerStatus = PlayerConnectionStatus.none;
    _currentlyPlayingUri = null;
    _isSdkPlayerPaused = true;
    _currentSpotifyTrackDetails = null;
    _playerConnectionErrorMsg = null;
    _spotifyPositionDataStreamController
        .add(PositionData(Duration.zero, Duration.zero, Duration.zero));
    _currentContextTracks = [];
    _updateAndNotify();
  }

  @override
  void dispose() {
    _logger.i("SpotifyPlaybackProvider disposing.");
    _playerController.dispose();
    _spotifyPositionDataStreamController.close();
    super.dispose();
  }

  // Placeholder for _playlistTracksCache if _updateCurrentSpotifyTrackDetails needs broader access
  // This should ideally be managed more centrally if the provider needs to look up any track.
  Map<String, List<SpotifyTrackSimple>> get _playlistTracksCache => {};
}
