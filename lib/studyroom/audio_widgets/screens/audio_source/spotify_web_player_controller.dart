// lib/studyroom/audio_widgets/spotify_web_player_controller.dart

import 'dart:js_util' as js_util;
import 'package:js/js.dart';

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
    if (_isInitialized) {
      print(
          "Dart: Player controller init() called, but already initialized. If re-initialization is needed, call dispose() first.");
      // Optionally, if _isReady is false, you could try to reconnect or re-init,
      // but the SDK's connect() should handle retries.
      // For now, we prevent re-running the full init logic.
      if (!_isReady && spotifyPlayerInstance != null) {
        // spotifyPlayerInstance is from @JS('spotifyPlayer')
        print(
            "Dart: Player was initialized but not ready, attempting to connect SDK player again.");
        try {
          final player = spotifyPlayerInstance; // Get the JS player object
          if (player != null) {
            js_util.callMethod(player, 'connect', []);
          }
        } catch (e) {
          print("Dart: Error trying to reconnect existing player instance: $e");
        }
      }
      return;
    }

    if (!js_util.hasProperty(js_util.globalThis, 'Spotify')) {
      final errorMsg =
          "Spotify SDK global object not found. Ensure SDK script is loaded in index.html before interop script.";
      print("Dart: $errorMsg");
      onPlayerError?.call(errorMsg);
      return;
    }

    try {
      _isInitialized = true; // Mark that init has been attempted
      _isReady = false; // Reset ready state on new init
      _deviceId = null;

      initializeSpotifyPlayer(
        accessToken,
        playerName,
        allowInterop((String id) {
          // onReadyCallback
          print('Dart: Player Ready with Device ID: $id');
          _deviceId = id;
          _isReady = true; // Player is now ready
          onPlayerReady?.call(id);
        }),
        allowInterop((dynamic jsState) {
          // onStateChangeCallback
          onPlayerStateChanged?.call(jsState);
        }),
        allowInterop((dynamic error) {
          // onPlayerErrorCallback
          String message = "Unknown SDK error";
          if (error != null && js_util.hasProperty(error, 'message')) {
            message = js_util.getProperty(error, 'message');
          }
          print("Dart: Player Error: $message");
          _isReady = false; // Player is not in a ready state due to error
          // _isInitialized might remain true, indicating init was attempted but failed to become ready
          onPlayerError?.call(message);
        }),
        allowInterop((String id) {
          // onNotReadyCallback
          print(
              'Dart: Player Not Ready. Device ID: $id (was previously ready).');
          _isReady = false; // Player is no longer ready
          // Keep _deviceId as it was the last known, but player is not active with it
          onPlayerNotReady?.call(id);
        }),
      );
    } catch (e) {
      final errorMsg = "Error calling initializeSpotifyPlayer from Dart: $e";
      print(errorMsg);
      _isInitialized = false; // Init attempt failed
      onPlayerError?.call(errorMsg);
    }
  }

  void togglePlay() {
    if (isPlayerInitializedAndReady) playerTogglePlay();
  }

  void next() {
    if (isPlayerInitializedAndReady) playerNextTrack();
  }

  void previous() {
    if (isPlayerInitializedAndReady) playerPreviousTrack();
  }

  String? getCurrentSdkDeviceId() {
    // Rely on the _deviceId set by the 'ready' callback
    if (isPlayerInitializedAndReady) {
      return _deviceId;
    }
    return null;
  }

  void dispose() {
    print(
        "Dart: Disposing SpotifyWebPlayerController. Initialized: $_isInitialized, Ready: $_isReady");
    if (_isInitialized) {
      // Call disconnect only if init was ever attempted
      try {
        disconnectSpotifyPlayer(); // Call the new JS function
      } catch (e) {
        print("Dart: Error calling disconnectSpotifyPlayer from Dart: $e");
      }
    }
    _isInitialized = false;
    _isReady = false;
    _deviceId = null;
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
