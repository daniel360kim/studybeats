import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// Project specific imports (adjust paths as necessary)
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/colors.dart'; // Ensure kFlourishBlackish & kFlourishAdobe are defined
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/audio_source_type.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';

// For parsing JS player state object from Spotify SDK
import 'dart:js_util' as js_util;

import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_web_player_controller.dart';

// Define internal view states for the switcher
enum _SwitcherView {
  selection,
  spotifyLoading,
  spotifyPlaylists,
  spotifyPlaylistTracks,
  spotifyError
}

// Enum to track the last failed action for the retry button
enum _LastFailedAction { none, fetchPlaylists, fetchTracks }

class AudioSourceSwitcher extends StatefulWidget {
  final AudioSourceType initialAudioSource;
  final ValueChanged<AudioSourceType> onAudioSourceChanged;
  final VoidCallback? onClose;

  const AudioSourceSwitcher({
    super.key,
    required this.initialAudioSource,
    required this.onAudioSourceChanged,
    this.onClose,
  });

  @override
  State<AudioSourceSwitcher> createState() => _AudioSourceSwitcherState();
}

class _AudioSourceSwitcherState extends State<AudioSourceSwitcher> {
  late AudioSourceType _selectedSource;
  _SwitcherView _currentView = _SwitcherView.selection;

  // Spotify Data & State
  List<SpotifyPlaylistSimple>? _userPlaylists;
  final Map<String, List<SpotifyTrackSimple>> _playlistTracksCache = {};
  SpotifyPlaylistSimple? _selectedPlaylistForTracksView;
  String? _currentlyPlayingUri;
  bool _isSdkPlayerPaused = true;

  // Loading/Error State
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';
  String _spotifyErrorMsg = '';
  _LastFailedAction _lastFailedAction = _LastFailedAction.none;

  // Services & Logger
  late SpotifyAuthService _authService; // Initialized in didChangeDependencies
  final SpotifyApiService _apiService = SpotifyApiService();
  final _logger = getLogger('AudioSourceSwitcher');

  // Spotify Web Playback SDK Controller
  final SpotifyWebPlayerController _playerController =
      SpotifyWebPlayerController();

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialAudioSource;
    _logger.i("initState: Initial source: $_selectedSource");
    _setupPlayerControllerListeners();
    // _authService is NOT initialized here yet.
  }

  void _setupPlayerControllerListeners() {
    _playerController.onPlayerReady = (deviceId) {
      _logger.i("Spotify Web SDK Player is READY. Device ID: $deviceId");
      _showSnackbar("In-app Spotify player connected!", Colors.green);
      if (mounted) setState(() {});
    };

    _playerController.onPlayerStateChanged = (dynamic jsPlayerState) {
      if (!mounted) return;
      if (jsPlayerState == null) {
        _logger.i(
            "SDK State: Player state is null (e.g., disconnected or error).");
        if (_currentlyPlayingUri != null || !_isSdkPlayerPaused) {
          setStateIfMounted(() {
            _currentlyPlayingUri = null;
            _isSdkPlayerPaused = true;
          });
        }
        return;
      }
      try {
        final trackWindow = js_util.getProperty(jsPlayerState, 'track_window');
        final currentTrackJs =
            js_util.getProperty(trackWindow, 'current_track');
        String? sdkTrackUri;

        if (currentTrackJs != null) {
          sdkTrackUri = js_util.getProperty(currentTrackJs, 'uri');
        }
        final bool sdkIsPaused = js_util.getProperty(jsPlayerState, 'paused');

        if (_currentlyPlayingUri != sdkTrackUri ||
            _isSdkPlayerPaused != sdkIsPaused) {
          setStateIfMounted(() {
            _currentlyPlayingUri = sdkTrackUri;
            _isSdkPlayerPaused = sdkIsPaused;
          });
          _logger
              .d("SDK State Updated: URI: $sdkTrackUri, Paused: $sdkIsPaused");
        }
      } catch (e, stacktrace) {
        _logger.e("Error parsing SDK player state: $e", stackTrace: stacktrace);
      }
    };

    _playerController.onPlayerError = (errorMsg) {
      _logger.e("Spotify Web SDK Player ERROR: $errorMsg");
      _showSnackbar("Spotify Player Error: $errorMsg", Colors.redAccent,
          durationSeconds: 5);
      if (mounted) setStateIfMounted(() {});
    };

    _playerController.onPlayerNotReady = (deviceId) {
      _logger.w("Spotify Web SDK Player NOT READY for device: $deviceId.");
      _showSnackbar("In-app Spotify player ($deviceId) disconnected.",
          Colors.orangeAccent);
      if (mounted) {
        setStateIfMounted(() {
          _isSdkPlayerPaused = true;
        });
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newAuthServiceFromProvider =
        Provider.of<SpotifyAuthService>(context, listen: false);

    bool needsInitializationOrUpdate = false;

    try {
      if (_authService != newAuthServiceFromProvider) {
        _logger.i(
            "didChangeDependencies: SpotifyAuthService instance from Provider has changed.");
        needsInitializationOrUpdate = true;
      }
    } catch (e) {
      _logger.e(
          "didChangeDependencies: Error comparing _authService: $e. Assuming re-initialization is needed.");
      needsInitializationOrUpdate = true;
    }

    if (needsInitializationOrUpdate) {
      _authService = newAuthServiceFromProvider;
      _logger.i(
          "didChangeDependencies: _authService instance has been set/updated. Authenticated: ${_authService.isAuthenticated}");

      if (_authService.isAuthenticated &&
          _authService.accessToken != null &&
          !_playerController.isPlayerInitializedAndReady) {
        _logger.i(
            "didChangeDependencies (after _authService set): Auth is true. Attempting SDK player init.");
        _playerController.init(
            _authService.accessToken!, "StudyBeats Web Player");
      } else if (!_authService.isAuthenticated &&
          _playerController.isPlayerInitializedAndReady) {
        _logger.w(
            "didChangeDependencies (after _authService set): Auth lost. Disposing player.");
        _playerController.dispose();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentView != _SwitcherView.selection) {
            _clearSpotifyData(clearSelection: true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color backgroundColor,
      {int durationSeconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: Duration(seconds: durationSeconds),
    ));
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _setLoading(bool loading, {String message = 'Loading...'}) {
    if (!mounted || (_isLoading == loading && _loadingMessage == message))
      return;
    setStateIfMounted(() {
      _isLoading = loading;
      if (loading) {
        _currentView = _SwitcherView.spotifyLoading;
        _loadingMessage = message;
        _spotifyErrorMsg = '';
        _lastFailedAction = _LastFailedAction.none;
      }
    });
  }

  void _setError(String message, _LastFailedAction failedAction) {
    _logger.e("Setting error state: $message, Failed Action: $failedAction");
    if (!mounted) return;
    setStateIfMounted(() {
      _isLoading = false;
      _currentView = _SwitcherView.spotifyError;
      _spotifyErrorMsg = message;
      _lastFailedAction = failedAction;
    });
  }

  void _clearSpotifyData(
      {bool clearSelection = false, bool keepUserPlaylists = false}) {
    if (!mounted) return;
    setStateIfMounted(() {
      if (!keepUserPlaylists) _userPlaylists = null;
      _playlistTracksCache.clear();
      _selectedPlaylistForTracksView = null;
      _spotifyErrorMsg = '';
      _isLoading = false;
      _lastFailedAction = _LastFailedAction.none;
      if (clearSelection) {
        _selectedSource = AudioSourceType.lofi;
        _currentView = _SwitcherView.selection;
        widget.onAudioSourceChanged(AudioSourceType.lofi);
      } else if (_currentView != _SwitcherView.selection) {
        // This condition needs _authService to be initialized.
        // It's generally called after auth state changes or user actions, so _authService should be set.
        try {
          _currentView = _authService.isAuthenticated
              ? _SwitcherView.spotifyPlaylists
              : _SwitcherView.selection;
        } catch (e) {
          _logger.e("Error setting current view: $e");
          _currentView = _SwitcherView.selection;
        }
      }
    });
    _logger.i(
        "Cleared Spotify data. Clear selection: $clearSelection, Keep User Playlists: $keepUserPlaylists");
  }

  void _selectSource(AudioSourceType source) {
    // _authService should be initialized by didChangeDependencies before user can interact to call this.
    _logger
        .i("Source selected: $source. Auth: ${_authService.isAuthenticated}");
    if (source == AudioSourceType.lofi) {
      if (_selectedSource != source ||
          _currentView != _SwitcherView.selection) {
        setStateIfMounted(() {
          _selectedSource = source;
          _currentView = _SwitcherView.selection;
          _selectedPlaylistForTracksView = null;
        });
        widget.onAudioSourceChanged(source);
      }
    } else if (source == AudioSourceType.spotify) {
      setStateIfMounted(() {
        _selectedSource = source;
      });
      widget.onAudioSourceChanged(source);
      if (_authService.isAuthenticated &&
          _authService.accessToken != null &&
          !_playerController.isPlayerInitializedAndReady) {
        _logger
            .i("Spotify source selected: Attempting to initialize SDK player.");
        _playerController.init(
            _authService.accessToken!, "StudyBeats Web Player");
      }
    }
  }

  void _onAuthSuccess() {
    // _authService should be initialized.
    _logger.i(
        "Auth successful. Fetching playlists & ensuring SDK player is initialized.");
    if (_authService.isAuthenticated &&
        _authService.accessToken != null &&
        !_playerController.isPlayerInitializedAndReady) {
      _playerController.init(
          _authService.accessToken!, "StudyBeats Web Player");
    }
    _fetchUserPlaylists();
  }

  void _logoutSpotify() {
    // _authService should be initialized.
    _logger.i("Logging out Spotify user.");
    _authService.logout();
    // Player disposal and data clearing will be handled by didChangeDependencies or Consumer's post frame callback
    // when they detect authService.isAuthenticated is false.
  }

  Future<void> _fetchUserPlaylists({bool forceRefresh = false}) async {
    // _authService should be initialized.
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error. Please login again.',
          _LastFailedAction.fetchPlaylists);
      return;
    }
    if (_userPlaylists != null && !forceRefresh) {
      _logger.d("Using cached user playlists.");
      if (mounted)
        setStateIfMounted(() => _currentView = _SwitcherView.spotifyPlaylists);
      return;
    }
    _setLoading(true, message: 'Loading your playlists...');
    try {
      final playlistsData = await _apiService
          .getUserPlaylists(_authService.accessToken!, limit: 50);
      if (!mounted) return;
      if (playlistsData != null && playlistsData['items'] is List) {
        final List<dynamic> items = playlistsData['items'];
        _userPlaylists = items.map((item) => _parsePlaylist(item)).toList();
        setStateIfMounted(() {
          _isLoading = false;
          _currentView = _SwitcherView.spotifyPlaylists;
        });
      } else {
        throw Exception("Failed to parse user playlists or no data returned.");
      }
    } catch (e, stacktrace) {
      _logger.e("Error fetching user playlists: $e",
          error: e, stackTrace: stacktrace);
      _setError(
          'Could not load your playlists.', _LastFailedAction.fetchPlaylists);
    }
  }

  Future<void> _fetchPlaylistTracks(SpotifyPlaylistSimple playlist,
      {bool forceRefresh = false}) async {
    // _authService should be initialized.
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error fetching tracks.',
          _LastFailedAction.fetchTracks);
      return;
    }
    _selectedPlaylistForTracksView = playlist;
    if (_playlistTracksCache.containsKey(playlist.id) && !forceRefresh) {
      if (mounted)
        setStateIfMounted(
            () => _currentView = _SwitcherView.spotifyPlaylistTracks);
      return;
    }
    _setLoading(true, message: 'Loading tracks for "${playlist.name}"...');
    try {
      final tracksData = await _apiService.getPlaylistTracks(
          _authService.accessToken!, playlist.id,
          limit: 100);
      if (!mounted) return;
      if (tracksData != null && tracksData['items'] is List) {
        final List<dynamic> items = tracksData['items'];
        final tracks = items
            .map((item) => _parseTrack(item))
            .whereType<SpotifyTrackSimple>()
            .toList();
        _playlistTracksCache[playlist.id] = tracks;
        setStateIfMounted(() {
          _isLoading = false;
          _currentView = _SwitcherView.spotifyPlaylistTracks;
        });
      } else {
        throw Exception("Failed to parse tracks or no data returned.");
      }
    } catch (e, stacktrace) {
      _logger.e("Error fetching tracks for ${playlist.id}: $e",
          error: e, stackTrace: stacktrace);
      _setError('Could not load tracks for "${playlist.name}".',
          _LastFailedAction.fetchTracks);
    }
  }

  SpotifyPlaylistSimple _parsePlaylist(Map<String, dynamic> item) {
    return SpotifyPlaylistSimple(
      id: item['id'] ?? 'unknown_id_${DateTime.now().millisecondsSinceEpoch}',
      name: item['name'] ?? 'Unknown Playlist',
      imageUrl: (item['images'] != null && (item['images'] as List).isNotEmpty)
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
      _logger.w("Skipping invalid or local track item: $item");
      return null;
    }
    String artists = (track['artists'] as List<dynamic>?)
            ?.map((artist) => artist['name'] as String)
            .join(', ') ??
        'Unknown Artist';
    String? albumImageUrl = (track['album']?['images'] != null &&
            (track['album']['images'] as List).isNotEmpty)
        ? track['album']['images'][0]['url']
        : null;
    return SpotifyTrackSimple(
      id: track['id'] as String,
      name: track['name'] ?? 'Unknown Track',
      artists: artists,
      albumName: track['album']?['name'],
      albumImageUrl: albumImageUrl,
      uri: track['uri'] as String,
      durationMs: track['duration_ms'] ?? 0,
    );
  }

  void _retryLastAction() {
    _logger.i("Retrying last failed action: $_lastFailedAction");
    if (!mounted) return;
    setStateIfMounted(() => _spotifyErrorMsg = '');
    switch (_lastFailedAction) {
      case _LastFailedAction.fetchPlaylists:
        _fetchUserPlaylists(forceRefresh: true);
        break;
      case _LastFailedAction.fetchTracks:
        if (_selectedPlaylistForTracksView != null) {
          _fetchPlaylistTracks(_selectedPlaylistForTracksView!,
              forceRefresh: true);
        } else {
          _fetchUserPlaylists(forceRefresh: true);
        }
        break;
      case _LastFailedAction.none:
        // _authService should be initialized.
        if (_authService.isAuthenticated) {
          _fetchUserPlaylists(forceRefresh: true);
        } else {
          _logger.i("Retry: User not authenticated, returning to selection.");
          setStateIfMounted(() => _currentView = _SwitcherView.selection);
        }
        break;
    }
  }

  Future<void> _startPlayback(String trackUri) async {
    // _authService should be initialized.
    _logger.i('Attempting to play track: $trackUri');
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _showSnackbar('Spotify authentication error. Please login again.',
          Colors.redAccent);
      return;
    }

    final sdkDeviceId = _playerController.getCurrentSdkDeviceId();

    if (_playerController.isPlayerInitializedAndReady &&
        sdkDeviceId != null &&
        sdkDeviceId.isNotEmpty) {
      _logger.i(
          'Using SDK Player (Device ID: $sdkDeviceId) to play track: $trackUri');
      _showSnackbar('Sending play command to in-app player…', Colors.blueGrey,
          durationSeconds: 2);

      try {
        final result = await _apiService.playItems(
          _authService.accessToken!,
          deviceId: sdkDeviceId,
          trackUris: [trackUri],
        );

        if (result == 'SUCCESS') {
          _logger.i(
              'Playback command successful for $trackUri on SDK device $sdkDeviceId');
          if (mounted) setStateIfMounted(() => _currentlyPlayingUri = trackUri);
        } else {
          _logger.w(
              'SDK Playback failed for $trackUri on device $sdkDeviceId (status=$result)');
          _showSnackbar(
              'Could not start playback: $result. Ensure Spotify Premium & check other devices.',
              Colors.orangeAccent,
              durationSeconds: 5);
        }
      } catch (e, stacktrace) {
        _logger.e('Exception during SDK playback attempt: $e',
            error: e, stackTrace: stacktrace);
        _showSnackbar(
            'Error trying to start playback in browser.', Colors.redAccent);
      }
    } else {
      _logger.w(
          'SDK Player not ready. Falling back to REST API play command for any active device.');
      _showSnackbar(
          'In-app player not ready. Playing on any active Spotify device...',
          Colors.orange,
          durationSeconds: 3);
      try {
        final result = await _apiService
            .playItems(_authService.accessToken!, trackUris: [trackUri]);
        if (result == 'SUCCESS') {
          _logger.i('Fallback Playback command successful for $trackUri');
          if (mounted) setStateIfMounted(() => _currentlyPlayingUri = trackUri);
          _showSnackbar(
              'Playback started on an active Spotify device (fallback).',
              Colors.green,
              durationSeconds: 3);
        } else {
          _logger.w('Fallback Playback failed for $trackUri (status=$result)');
          _showSnackbar(
              'Fallback playback failed: $result.', Colors.orangeAccent,
              durationSeconds: 4);
        }
      } catch (e, stacktrace) {
        _logger.e('Exception during fallback playback: $e',
            error: e, stackTrace: stacktrace);
        _showSnackbar(
            'Error during fallback playback attempt.', Colors.redAccent);
      }
    }
  }

  void _toggleSdkPlayerPlayback() {
    if (_playerController.isPlayerInitializedAndReady) {
      _playerController.togglePlay();
      _logger.i(
          "Toggle SDK Playback invoked. Current reported pause state by UI: $_isSdkPlayerPaused");
    } else {
      _showSnackbar("In-app player not connected.", Colors.orangeAccent);
    }
  }

  Widget _buildSourceCard({
    required String title,
    IconData? iconData,
    Widget? iconWidget,
    String? subtitle,
    Widget? subtitleWidget,
    Color? subtitleColor,
    required AudioSourceType sourceType,
    required bool isSelected,
    required VoidCallback onTap,
    bool showRipple = false,
    required bool isSpotifyAuthenticated, // Added this parameter
  }) {
    final Gradient? cardGradient = sourceType == AudioSourceType.spotify
        ? LinearGradient(
            colors: [
              const Color(0xFF1DB954).withOpacity(0.13),
              Colors.white.withOpacity(0.92)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.blue.shade100.withOpacity(0.19),
              Colors.white.withOpacity(0.92)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        gradient: cardGradient,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.17),
                  blurRadius: 13,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
        border: Border.all(
          color: isSelected
              ? (sourceType == AudioSourceType.spotify
                  ? const Color(0xFF1DB954)
                  : Theme.of(context).primaryColor)
              : Colors.grey.shade300,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          splashColor: Theme.of(context).primaryColor.withOpacity(0.14),
          highlightColor: Theme.of(context).primaryColor.withOpacity(0.09),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: isSelected ? 1.025 : 1.0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              child: Row(
                children: [
                  if (iconWidget != null)
                    iconWidget
                  else if (iconData != null)
                    Icon(iconData,
                        size: 32,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade700),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kFlourishBlackish,
                          ),
                        ),
                        if (subtitleWidget != null) ...[
                          const SizedBox(height: 5),
                          subtitleWidget,
                        ] else if (subtitle != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: subtitleColor ??
                                  (sourceType == AudioSourceType.spotify
                                      ? const Color(0xFF1DB954)
                                          .withOpacity(0.85)
                                      : Colors.blueGrey.shade400),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (sourceType == AudioSourceType.spotify &&
                      isSpotifyAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.redAccent, size: 20),
                      onPressed:
                          _logoutSpotify, // This uses the class member _authService
                      tooltip: "Logout Spotify",
                    ),
                  if (isSelected)
                    Icon(Icons.check_circle,
                        color: sourceType == AudioSourceType.spotify
                            ? const Color(0xFF1DB954)
                            : Theme.of(context).primaryColor,
                        size: 27),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayerControls() {
    SpotifyTrackSimple? trackDetails;
    if (_currentlyPlayingUri != null &&
        _selectedPlaylistForTracksView != null) {
      final cachedTracks =
          _playlistTracksCache[_selectedPlaylistForTracksView!.id];
      if (cachedTracks != null) {
        trackDetails = cachedTracks.firstWhere(
            (t) => t.uri == _currentlyPlayingUri,
            orElse: () => SpotifyTrackSimple(
                id: '',
                name: 'Unknown Track',
                artists: '...',
                uri: _currentlyPlayingUri!,
                durationMs: 0));
      }
    }
    trackDetails ??= SpotifyTrackSimple(
        id: '',
        name: 'Playing...',
        artists: 'Spotify',
        uri: _currentlyPlayingUri ?? 'spotify:unknown',
        durationMs: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          _buildImagePlaceholder(trackDetails.albumImageUrl, 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trackDetails.name,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(trackDetails.artists,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isSdkPlayerPaused ? Icons.play_arrow : Icons.pause,
                size: 22),
            onPressed: _toggleSdkPlayerPlayback,
            tooltip: _isSdkPlayerPaused ? "Play" : "Pause",
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifyPlaylistView() {
    final playlistsToDisplay = _userPlaylists;
    bool hasPlaylists =
        playlistsToDisplay != null && playlistsToDisplay.isNotEmpty;
    _logger.d("Build Playlist View. Count: ${playlistsToDisplay?.length}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: kFlourishBlackish.withOpacity(0.8), size: 20),
                onPressed: () => setStateIfMounted(() {
                      _currentView = _SwitcherView.selection;
                    }),
                tooltip: 'Back'),
            Expanded(
                child: Text("Your Playlists",
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kFlourishBlackish),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
            if (widget.onClose != null)
              IconButton(
                  icon: Icon(Icons.close,
                      color: kFlourishBlackish.withOpacity(0.6)),
                  onPressed: widget.onClose,
                  tooltip: 'Close')
            else
              const SizedBox(width: 48),
          ]),
        ),
        const Divider(height: 1, thickness: 0.5, indent: 10, endIndent: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RefreshIndicator(
              onRefresh: () => _fetchUserPlaylists(forceRefresh: true),
              child: (_userPlaylists == null && _isLoading)
                  ? _buildShimmerList(isPlaylist: true)
                  : !hasPlaylists
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                          'No playlists found. Pull to refresh or check Spotify.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: Colors.grey[600])))),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: playlistsToDisplay.length,
                          separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              thickness: 0.3,
                              indent: 70,
                              endIndent: 10),
                          itemBuilder: (context, index) {
                            final playlist = playlistsToDisplay[index];
                            return ListTile(
                              leading:
                                  _buildImagePlaceholder(playlist.imageUrl, 50),
                              title: Text(playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              subtitle: playlist.totalTracks > 0
                                  ? Text('${playlist.totalTracks} tracks',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[700]))
                                  : Text('Empty playlist',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500])),
                              onTap: () => _fetchPlaylistTracks(playlist),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6.0, horizontal: 10.0),
                            );
                          },
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpotifyPlaylistTracksView() {
    if (_selectedPlaylistForTracksView == null)
      return _buildErrorView("No playlist selected. Please go back.");

    final playlist = _selectedPlaylistForTracksView!;
    final tracksToDisplay = _playlistTracksCache[playlist.id];

    bool hasTracks = tracksToDisplay != null && tracksToDisplay.isNotEmpty;
    _logger.d(
        "Build Tracks View for ${playlist.name}. Cached Count: ${tracksToDisplay?.length}, Current Playing URI: $_currentlyPlayingUri");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: kFlourishBlackish.withOpacity(0.8), size: 20),
                onPressed: () => setStateIfMounted(() {
                      _currentView = _SwitcherView.spotifyPlaylists;
                    }),
                tooltip: 'Back to Playlists'),
            Expanded(
                child: Text(playlist.name,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kFlourishBlackish),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
            if (widget.onClose != null)
              IconButton(
                  icon: Icon(Icons.close,
                      color: kFlourishBlackish.withOpacity(0.6)),
                  onPressed: widget.onClose,
                  tooltip: 'Close')
            else
              const SizedBox(width: 48),
          ]),
        ),
        const Divider(height: 1, thickness: 0.5, indent: 10, endIndent: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RefreshIndicator(
              onRefresh: () =>
                  _fetchPlaylistTracks(playlist, forceRefresh: true),
              child: (tracksToDisplay == null && _isLoading)
                  ? _buildShimmerList(isPlaylist: false)
                  : !hasTracks
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                          'No tracks found in this playlist. Pull to refresh.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: Colors.grey[600])))),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tracksToDisplay.length,
                          itemBuilder: (context, index) {
                            final track = tracksToDisplay[index];
                            bool isCurrentlyPlayingThisTrack =
                                track.uri == _currentlyPlayingUri;
                            return ListTile(
                              tileColor: isCurrentlyPlayingThisTrack
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1)
                                  : null,
                              leading: _buildImagePlaceholder(
                                  track.albumImageUrl, 40),
                              title: Text(track.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: isCurrentlyPlayingThisTrack
                                          ? FontWeight.w600
                                          : FontWeight.w500)),
                              subtitle: Text(track.artists,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.grey[700])),
                              trailing: isCurrentlyPlayingThisTrack
                                  ? Icon(
                                      _isSdkPlayerPaused
                                          ? Icons.play_circle_filled
                                          : Icons.volume_up,
                                      size: 20,
                                      color: _isSdkPlayerPaused
                                          ? Colors.grey.shade600
                                          : Theme.of(context).primaryColor)
                                  : Text(track.formattedDuration,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[700])),
                              onTap: () {
                                _logger.i(
                                    "Tapped track: ${track.name} (URI: ${track.uri})");
                                if (isCurrentlyPlayingThisTrack) {
                                  _toggleSdkPlayerPlayback();
                                } else {
                                  _startPlayback(track.uri);
                                }
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 10.0),
                              dense: true,
                            );
                          },
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    _logger.d("Building Generic Loading View. Message: $_loadingMessage");
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: kFlourishAdobe,
            ),
            const SizedBox(height: 20),
            Text(_loadingMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList({required bool isPlaylist}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => ListTile(
            leading: Container(
                width: isPlaylist ? 50 : 40,
                height: isPlaylist ? 50 : 40,
                color: Colors.white),
            title: Container(
                height: 16,
                color: Colors.white,
                margin: EdgeInsets.only(right: isPlaylist ? 0 : 50)),
            subtitle: Container(height: 12, width: 100, color: Colors.white),
            trailing: isPlaylist
                ? null
                : Container(height: 12, width: 30, color: Colors.white),
            contentPadding: EdgeInsets.symmetric(
                vertical: isPlaylist ? 6.0 : 4.0, horizontal: 10.0),
            dense: !isPlaylist,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    _logger.d(
        "Building Error View. Message: $errorMessage, LastFailed: $_lastFailedAction");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 20),
            Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : "An unexpected error occurred.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent),
            ),
            const SizedBox(height: 25),
            if (_lastFailedAction != _LastFailedAction.none)
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10)),
                onPressed: _retryLastAction,
              ),
            const SizedBox(height: 10),
            TextButton(
              child: Text("Go Back to Selection",
                  style: GoogleFonts.inter(color: Colors.blueGrey[700])),
              onPressed: () {
                _logger.i("Go Back from Error view pressed.");
                setStateIfMounted(() {
                  _clearSpotifyData(keepUserPlaylists: true);
                  _currentView = _SwitcherView.selection;
                });
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String? imageUrl, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image,
                      color: Colors.white70, size: size * 0.5)),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                        width: size, height: size, color: Colors.white));
              },
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.0)),
              child: Icon(Icons.music_note,
                  color: Colors.white70, size: size * 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
        topLeft: Radius.circular(40.0), topRight: Radius.circular(40.0));
    _logger.d(
        "Build method. View: $_currentView, Source: $_selectedSource, SDK Ready: ${_playerController.isPlayerInitializedAndReady}, Playing URI: $_currentlyPlayingUri");

    return Consumer<SpotifyAuthService>(
      builder: (context, authServiceFromConsumer, child) {
        // didChangeDependencies is responsible for keeping the class member _authService in sync.
        // Use authServiceFromConsumer for conditions directly within this build pass.

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isLoading &&
              _loadingMessage.contains('Redirecting') &&
              authServiceFromConsumer.isAuthenticated) {
            _logger.i(
                "PostFrame (Consumer): Auth completed after redirect. Calling _onAuthSuccess.");
            _onAuthSuccess();
          } else if ((_currentView == _SwitcherView.spotifyPlaylists ||
                  _currentView == _SwitcherView.spotifyPlaylistTracks) &&
              !authServiceFromConsumer.isAuthenticated) {
            _logger.w(
                "PostFrame (Consumer): Auth lost while viewing Spotify content. Clearing data and player.");
            if (_playerController.isPlayerInitializedAndReady) {
              // Check before disposing
              _playerController.dispose();
            }
            _clearSpotifyData(clearSelection: true);
          }
        });

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.75,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300.withOpacity(0.6),
                          borderRadius: borderRadius),
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            color: Colors.white.withOpacity(0.95)),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child,
                                  Animation<double> animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _buildCurrentView(authServiceFromConsumer),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentView(SpotifyAuthService currentAuthService) {
    if (_isLoading && _currentView == _SwitcherView.spotifyLoading) {
      return KeyedSubtree(
          key: const ValueKey('loadingView'), child: _buildLoadingView());
    }
    if (_currentView == _SwitcherView.spotifyError &&
        _spotifyErrorMsg.isNotEmpty) {
      return KeyedSubtree(
          key: ValueKey('errorView_$_spotifyErrorMsg'),
          child: _buildErrorView(_spotifyErrorMsg));
    }

    switch (_currentView) {
      case _SwitcherView.selection:
        return KeyedSubtree(
            key: const ValueKey('selectionView'),
            child: _buildSourceSelectionView(currentAuthService));
      case _SwitcherView.spotifyPlaylists:
        if (!currentAuthService.isAuthenticated) {
          _logger.w(
              "Attempted to build SpotifyPlaylistView without auth, redirecting to selection.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              setStateIfMounted(() => _currentView = _SwitcherView.selection);
          });
          return KeyedSubtree(
              key: const ValueKey('selectionView_auth_redirect'),
              child: _buildSourceSelectionView(currentAuthService));
        }
        return KeyedSubtree(
            key: const ValueKey('playlistsView'),
            child: _buildSpotifyPlaylistView());
      case _SwitcherView.spotifyPlaylistTracks:
        if (!currentAuthService.isAuthenticated) {
          _logger.w(
              "Attempted to build SpotifyPlaylistTracksView without auth, redirecting to selection.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              setStateIfMounted(() => _currentView = _SwitcherView.selection);
          });
          return KeyedSubtree(
              key: const ValueKey('selectionView_auth_redirect_tracks'),
              child: _buildSourceSelectionView(currentAuthService));
        }
        return KeyedSubtree(
            key: ValueKey(
                'tracksView_${_selectedPlaylistForTracksView?.id ?? "none"}'),
            child: _buildSpotifyPlaylistTracksView());
      default:
        _logger.w(
            "Reached default case in _buildCurrentView with view: $_currentView. Falling back to selection.");
        return KeyedSubtree(
            key: const ValueKey('defaultFallbackSelectionView'),
            child: _buildSourceSelectionView(currentAuthService));
    }
  }

  Widget _buildSourceSelectionView(SpotifyAuthService currentAuthService) {
    bool isSpotifyAuthenticated = currentAuthService.isAuthenticated;
    bool isSdkPlayerReady = _playerController.isPlayerInitializedAndReady;
    _logger.d(
        "Build Selection View. Selected: $_selectedSource, Auth from param: $isSpotifyAuthenticated, SDK Ready: $isSdkPlayerReady");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Choose your audio source',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish)),
            Row(children: [
              if (widget.onClose != null)
                IconButton(
                    icon: Icon(Icons.close,
                        color: kFlourishBlackish.withOpacity(0.7)),
                    onPressed: widget.onClose,
                    tooltip: 'Close Panel'),
            ]),
          ]),
          const SizedBox(height: 28),
          _buildSourceCard(
            title: 'Lofi Radio',
            iconData: Icons.radio,
            sourceType: AudioSourceType.lofi,
            isSelected: _selectedSource == AudioSourceType.lofi,
            onTap: () => _selectSource(AudioSourceType.lofi),
            isSpotifyAuthenticated: isSpotifyAuthenticated,
          ),
          const SizedBox(height: 18),
          Builder(builder: (context) {
            String spotifySubtitle;
            Widget? spotifyIconWidget;

            spotifyIconWidget = CircleAvatar(
              radius: 18,
              backgroundColor: isSpotifyAuthenticated
                  ? Colors.green.shade600
                  : Colors.grey.shade400,
              child: Image.asset('assets/brand/spotify.png',
                  width: 20, height: 20, color: Colors.white),
            );

            if (isSpotifyAuthenticated) {
              if (isSdkPlayerReady) {
                spotifySubtitle = "🎧 Player Connected. View Playlists.";
              } else if (_playerController.isPlayerInitializedAndReady ==
                      false &&
                  currentAuthService.accessToken != null) {
                spotifySubtitle =
                    "⚠️ Player connecting... Tap to retry or view playlists.";
              } else {
                spotifySubtitle = "🎧 Tap to View Playlists";
              }
            } else {
              spotifySubtitle = "Tap to connect Spotify";
            }

            return _buildSourceCard(
              title: 'Spotify',
              iconWidget: spotifyIconWidget,
              subtitleWidget: isSpotifyAuthenticated
                  ? GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setStateIfMounted(() =>
                            _currentView = _SwitcherView.spotifyPlaylists);
                        if (_userPlaylists == null)
                          _fetchUserPlaylists(); // Uses class member _authService
                        if (!_playerController.isPlayerInitializedAndReady &&
                            _authService.accessToken != null) {
                          // Uses class member _authService
                          _playerController.init(_authService.accessToken!,
                              "StudyBeats Web Player");
                        }
                      },
                      child: Text(
                        spotifySubtitle,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.green.shade700),
                      ),
                    )
                  : Text(spotifySubtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey.shade700)),
              sourceType: AudioSourceType.spotify,
              isSelected: _selectedSource == AudioSourceType.spotify,
              onTap: () {
                _selectSource(AudioSourceType
                    .spotify); // Uses class member _authService internally
                if (!isSpotifyAuthenticated) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text("Spotify Login Required",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                          "Spotify login is required to view and play your playlists.",
                          style: GoogleFonts.inter()),
                      actions: [
                        TextButton(
                          child: Text("Cancel",
                              style:
                                  GoogleFonts.inter(color: Colors.grey[700])),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.white,
                          ),
                          child: Text("Connect Spotify",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _setLoading(true,
                                message: 'Redirecting to Spotify for login...');
                            _authService
                                .login(); // Uses class member _authService
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  setStateIfMounted(
                      () => _currentView = _SwitcherView.spotifyPlaylists);
                  if (_userPlaylists == null)
                    _fetchUserPlaylists(); // Uses class member _authService
                }
              },
              showRipple: true,
              isSpotifyAuthenticated: isSpotifyAuthenticated,
            );
          }),
          const Spacer(),
          if (isSpotifyAuthenticated &&
              _playerController.isPlayerInitializedAndReady &&
              _currentlyPlayingUri != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildMiniPlayerControls(),
            ),
        ],
      ),
    );
  }
}
