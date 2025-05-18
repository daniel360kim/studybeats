// lib/studyroom/audio_widgets/spotify_web_player_controller.dart

import 'dart:js_util' as js_util;
import 'package:js/js.dart';
import 'package:studybeats/log_printer.dart';

// These functions correspond to the ones in spotify_player_interop.js
@JS()
external void initializeSpotifyPlayer(
    String token,
    String playerName,
    Function onReadyCallback,
    Function onStateChangeCallback,
    Function onPlayerErrorCallback,
    Function onNotReadyCallback);

@JS()
external void playerTogglePlay();
@JS()
external void playerNextTrack();
@JS()
external void playerPreviousTrack();
@JS()
external String?
    getLocalDeviceId(); // Keep if used, though _deviceId is now primary

@JS() // NEW: Binding for the disconnect function
external void disconnectSpotifyPlayer();

class SpotifyWebPlayerController {
  final _logger = getLogger('SpotifyWebPlayerController');
  String? _deviceId;
  String? get deviceId => _deviceId;

  bool _isInitialized =
      false; // Tracks if init() has been called and SDK loaded player
  bool _isReady =
      false; // Tracks if the 'ready' event with a device_id has fired

  // Combined getter for convenience
  bool get isPlayerInitializedAndReady =>
      _isInitialized && _isReady && _deviceId != null;

  // Callbacks for Flutter UI updates
  Function(String deviceId)? onPlayerReady;
  Function(dynamic jsPlayerState)? onPlayerStateChanged;
  Function(String? errorMsg)? onPlayerError;
  Function(String deviceId)? onPlayerNotReady;

  void init(String accessToken, String playerName) {
    _logger.d(
        "init() called. AccessToken: ${accessToken.isNotEmpty ? "provided" : "empty"}, PlayerName: '$playerName'. Current state - Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");

    if (_isInitialized) {
      _logger.w(
          "Player controller init() called, but already initialized. Current state - Initialized: $_isInitialized, Ready: $_isReady. If re-initialization is needed, call dispose() first.");
      if (!_isReady && spotifyPlayerInstance != null) {
        _logger.i(
            "Player was initialized but not ready (SDK Player: ${spotifyPlayerInstance != null ? "exists" : "null"}), attempting to connect SDK player again.");
        try {
          final player = spotifyPlayerInstance;
          if (player != null) {
            js_util.callMethod(player, 'connect', []);
            _logger.d("Called connect() on existing JS player instance.");
          } else {
            _logger.w(
                "spotifyPlayerInstance is null, cannot call connect() during re-init attempt.");
          }
        } catch (e, s) {
          _logger.e("Error trying to reconnect existing player instance.",
              error: e, stackTrace: s);
        }
      }
      return;
    }

    if (!js_util.hasProperty(js_util.globalThis, 'Spotify')) {
      final errorMsg =
          "Spotify SDK global object not found. Ensure SDK script is loaded in index.html before interop script.";
      _logger.e(errorMsg);
      onPlayerError?.call(errorMsg);
      return;
    }

    try {
      _isInitialized = true; // Mark that init has been attempted
      _isReady = false; // Reset ready state on new init
      _deviceId = null;
      _logger.d(
          "Attempting to initialize Spotify Player via JS interop. State reset: _isInitialized=true, _isReady=false, _deviceId=null");

      initializeSpotifyPlayer(
        accessToken,
        playerName,
        allowInterop((String id) {
          // onReadyCallback
          _logger.i('JS onReadyCallback: Player Ready with Device ID: $id');
          _deviceId = id;
          _isReady = true;
          onPlayerReady?.call(id);
        }),
        allowInterop((dynamic jsState) {
          // onStateChangeCallback
          _logger.d('JS onStateChangeCallback: Player state changed.');
          onPlayerStateChanged?.call(jsState);
        }),
        allowInterop((dynamic error) {
          // onPlayerErrorCallback
          String message = "Unknown SDK error";
          if (error != null && js_util.hasProperty(error, 'message')) {
            message = js_util.getProperty(error, 'message');
          }
          _logger.e("JS onPlayerErrorCallback: $message", error: error);
          _isReady = false;
          onPlayerError?.call(message);
        }),
        allowInterop((String id) {
          // onNotReadyCallback
          _logger.w(
              'JS onNotReadyCallback: Player Not Ready. Device ID: $id (was previously ready).');
          _isReady = false;
          onPlayerNotReady?.call(id);
        }),
      );
      _logger.d("JS initializeSpotifyPlayer function called successfully.");
    } catch (e, s) {
      final errorMsg = "Error calling initializeSpotifyPlayer from Dart: $e";
      _logger.e(errorMsg, error: e, stackTrace: s);
      _isInitialized = false; // Init attempt failed
      onPlayerError?.call(errorMsg);
    }
  }

  void togglePlay() {
    _logger.d("togglePlay() called.");
    if (isPlayerInitializedAndReady) {
      _logger.i("Executing JS playerTogglePlay().");
      try {
        playerTogglePlay();
      } catch (e, s) {
        _logger.e("Error calling JS playerTogglePlay().",
            error: e, stackTrace: s);
      }
    } else {
      _logger.w(
          "togglePlay() called but player not initialized and ready. State - Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");
    }
  }

  void next() {
    _logger.d("next() called.");
    if (isPlayerInitializedAndReady) {
      _logger.i("Executing JS playerNextTrack().");
      try {
        playerNextTrack();
      } catch (e, s) {
        _logger.e("Error calling JS playerNextTrack().",
            error: e, stackTrace: s);
      }
    } else {
      _logger.w(
          "next() called but player not initialized and ready. State - Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");
    }
  }

  void previous() {
    _logger.d("previous() called.");
    if (isPlayerInitializedAndReady) {
      _logger.i("Executing JS playerPreviousTrack().");
      try {
        playerPreviousTrack();
      } catch (e, s) {
        _logger.e("Error calling JS playerPreviousTrack().",
            error: e, stackTrace: s);
      }
    } else {
      _logger.w(
          "previous() called but player not initialized and ready. State - Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");
    }
  }

  String? getCurrentSdkDeviceId() {
    _logger.d(
        "getCurrentSdkDeviceId() called. isPlayerInitializedAndReady: $isPlayerInitializedAndReady, _deviceId: $_deviceId");
    if (isPlayerInitializedAndReady) {
      return _deviceId;
    }
    _logger.d(
        "getCurrentSdkDeviceId() returning null as player is not initialized and ready.");
    return null;
  }

  void dispose() {
    _logger.i(
        "dispose() called. Current state - Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");
    if (_isInitialized) {
      try {
        _logger.d("Calling JS disconnectSpotifyPlayer().");
        disconnectSpotifyPlayer(); // Call the new JS function
      } catch (e, s) {
        _logger.e("Error calling disconnectSpotifyPlayer from Dart.",
            error: e, stackTrace: s);
      }
    } else {
      _logger.d(
          "dispose() called, but player was not initialized. No JS disconnect needed.");
    }
    _isInitialized = false;
    _isReady = false;
    _deviceId = null;
    _logger.i(
        "Player controller disposed. State reset. Initialized: $_isInitialized, Ready: $_isReady, DeviceId: $_deviceId");
    // Clear callbacks if necessary, though they usually belong to the widget using this controller
    // onPlayerReady = null;
    // onPlayerStateChanged = null;
    // onPlayerError = null;
    // onPlayerNotReady = null;
  }
}

// This provides a way to access the JS 'spotifyPlayer' object if absolutely needed for methods
// not yet wrapped. Use with caution. Better to wrap specific methods.
@JS('spotifyPlayer')
external dynamic get spotifyPlayerInstance;
