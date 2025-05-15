@JS()
library spotify_web_playback;

import 'dart:async';
import 'dart:html';
import 'dart:js';
import 'dart:js_util' show jsify;
import 'package:http/http.dart' as http;
import 'package:js/js.dart';
import 'package:logger/logger.dart';
import 'package:studybeats/log_printer.dart';

enum PlaybackResult { success, failure }

@JS('Spotify.Player')
class _JSPlayer {
  external _JSPlayer(dynamic options);
  external bool connect();
  external void disconnect();
  external void addListener(String event, Function cb);
  external void removeListener(String event, Function cb);
}

class SpotifyWebPlaybackService {
  SpotifyWebPlaybackService({required this.logger});

  final Logger logger;
  _JSPlayer? _player;
  String? _deviceId;
  /// Public read‑only access to the active device ID (null until "ready").
  String? get deviceId => _deviceId;

  /// `true` when the SDK has fired the "ready" event and a device ID is known.
  bool get isReady => _deviceId != null;
  late String _accessToken; // keeps the most‑recent OAuth token
  bool _initialised = false;

  Future<void> initialize({
    required String accessToken,
    required void Function(String deviceId) onPlayerReady,
    required void Function(String? currentTrackUri) onPlayerStateChanged,
    required void Function(String message) onError,
  }) async {
    if (_initialised) return;
    _accessToken = accessToken;

// spotify_web_playback_service.dart  (inside initialize)

    if (context['Spotify'] == null) {
      // 👉 Provide an empty callback so the SDK doesn’t panic.
      if (context['onSpotifyWebPlaybackSDKReady'] == null) {
        context['onSpotifyWebPlaybackSDKReady'] = allowInterop(() {
          logger.i('Spotify Web Playback SDK ready (global callback).');
        });
      }

      final script = ScriptElement()
        ..src = 'https://sdk.scdn.co/spotify-player.js'
        ..async = true;
      document.body!.append(script);
      await _waitForSdk();
    }

    // 2. Create player
    _player = _JSPlayer(jsify({
      'name': 'StudyBeats Web Player',
      'volume': 0.8,
      'getOAuthToken': allowInterop((Function cb) => cb(_accessToken)),
    }));

    // 3. Attach listeners
    _player!.addListener(
      'ready',
      allowInterop((dynamic data) {
        _deviceId = data['device_id'];
        logger.i('Web Playback ready – deviceId=$_deviceId');
        onPlayerReady(_deviceId!);
      }),
    );

    _player!.addListener(
      'player_state_changed',
      allowInterop((dynamic state) {
        final uri = state?['track_window']?['current_track']?['uri'];
        onPlayerStateChanged(uri as String?);
      }),
    );

    for (final evt in [
      'initialization_error',
      'authentication_error',
      'account_error',
      'playback_error'
    ]) {
      _player!.addListener(evt, allowInterop((err) {
        logger.e('Web Playback $evt – ${err["message"]}');
        onError(err['message']);
      }));
    }

    // 4. Connect!
    final ok = _player!.connect();
    logger.i('Web Playback connect() returned $ok');
    _initialised = true;
  }

  Future<PlaybackResult> playTrack(String uri) async {
    if (_deviceId == null) {
      logger.w('No active Web Playback device');
      return PlaybackResult.failure;
    }
    final res = await http.put(
      Uri.parse(
          'https://api.spotify.com/v1/me/player/play?device_id=$_deviceId'),
      headers: {
        'Authorization': 'Bearer ${await _freshToken()}',
        'Content-Type': 'application/json'
      },
      body: '{"uris":["$uri"]}',
    );
    return (res.statusCode == 204 || res.statusCode == 202)
        ? PlaybackResult.success
        : PlaybackResult.failure;
  }

  Future<String> _freshToken() async {
    // TODO: hook into your auth-refresh flow; for now just return the last one.
    return _accessToken;
  }

  void dispose() => _player?.disconnect();

  Future<void> _waitForSdk() async {
    while (context['Spotify'] == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
