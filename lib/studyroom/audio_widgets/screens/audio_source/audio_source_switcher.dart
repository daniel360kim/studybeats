import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter.blur
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Project-specific imports
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart'; // ⬅️  enum + provider
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio/spotify_controller.dart';

// Views
import 'views/source_selection_view.dart';
import 'views/spotify_playlist_view.dart';
import 'views/spotify_tracks_view.dart';
import 'views/loading_view.dart';
import 'views/error_view.dart';

// Internal switcher view states
enum _SwitcherView {
  selection,
  spotifyLoading,
  spotifyPlaylists,
  spotifyPlaylistTracks,
  spotifyError,
}

// Tracks the last failed async action for the retry button
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
  _SwitcherView _currentView = _SwitcherView.selection;

  // Spotify data
  List<SpotifyPlaylistSimple>? _userPlaylists;
  final Map<String, List<SpotifyTrackSimple>> _playlistTracksCache = {};
  SpotifyPlaylistSimple? _selectedPlaylistForTracksView;

  // Loading & error state
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';
  String _spotifyErrorMsg = '';
  _LastFailedAction _lastFailedAction = _LastFailedAction.none;

  // Services & logger
  late SpotifyAuthService _authService; // set in didChangeDependencies
  final SpotifyApiService _apiService = SpotifyApiService();
  final _logger = getLogger('AudioSourceSwitcher');

  // Minimal toast overlay
  OverlayEntry? _toastOverlay;

  @override
  void initState() {
    super.initState();

    // Seed the global selection provider with the initial source
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AudioSourceSelectionProvider>()
          .setSource(widget.initialAudioSource);
      _logger
          .i('initState: Initial source = ${widget.initialAudioSource.name}');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<SpotifyAuthService>(context, listen: false);
  }

  @override
  void dispose() {
    _toastOverlay?.remove();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  Small helpers
  // ---------------------------------------------------------------------------

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _setLoading(bool loading, {String message = 'Loading...'}) {
    if (!mounted || (_isLoading == loading && _loadingMessage == message)) {
      return;
    }
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

  void _setError(String msg, _LastFailedAction failedAction) {
    _logger.e('Error: $msg');
    if (!mounted) return;
    setStateIfMounted(() {
      _isLoading = false;
      _currentView = _SwitcherView.spotifyError;
      _spotifyErrorMsg = msg;
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
        context
            .read<AudioSourceSelectionProvider>()
            .setSource(AudioSourceType.lofi);
        _currentView = _SwitcherView.selection;
        widget.onAudioSourceChanged(AudioSourceType.lofi);
      } else if (_currentView != _SwitcherView.selection) {
        _currentView = _SwitcherView.selection;
      }
    });
  }

  // ---------------------------------------------------------------------------
  //  Provider-backed playback actions
  // ---------------------------------------------------------------------------

  Future<void> _startPlayback(String trackUri) async {
    final playbackProvider = context.read<SpotifyPlaybackProvider>();
    playbackProvider.playTrack(
      trackUri,
      contextTracks: _selectedPlaylistForTracksView != null
          ? _playlistTracksCache[_selectedPlaylistForTracksView!.id]
          : null,
    );
  }

  void _toggleSdkPlayerPlayback() {
    context.read<SpotifyPlaybackProvider>().togglePlayPause();
  }

  void _handleRetryPlayerConnection() {
    context.read<SpotifyPlaybackProvider>().initializePlayer();
  }

  void _onAuthSuccess() {
    context.read<SpotifyPlaybackProvider>().initializePlayer();
    _fetchUserPlaylists();
  }

  void _logoutSpotify() {
    context.read<SpotifyPlaybackProvider>().disposePlayer();
    _authService.logout();
  }

  // ---------------------------------------------------------------------------
  //  Audio source selection
  // ---------------------------------------------------------------------------

  void _selectSource(AudioSourceType source) {
    _logger.i('Source selected: $source');

    final selectionProvider = context.read<AudioSourceSelectionProvider>();
    final current = selectionProvider.currentSource;

    if (source == AudioSourceType.lofi) {
      if (current != source || _currentView != _SwitcherView.selection) {
        selectionProvider.setSource(source);
        setStateIfMounted(() {
          _currentView = _SwitcherView.selection;
          _selectedPlaylistForTracksView = null;
        });
        widget.onAudioSourceChanged(source);
      }
    } else if (source == AudioSourceType.spotify) {
      if (current != source) selectionProvider.setSource(source);
      widget.onAudioSourceChanged(source);

      if (_authService.isAuthenticated && _authService.accessToken != null) {
        _handleRetryPlayerConnection();
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Spotify API helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchUserPlaylists({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error. Please login again.',
          _LastFailedAction.fetchPlaylists);
      return;
    }
    if (_userPlaylists != null && !forceRefresh) {
      setStateIfMounted(() => _currentView = _SwitcherView.spotifyPlaylists);
      return;
    }
    _setLoading(true, message: 'Loading your playlists...');
    try {
      final data = await _apiService.getUserPlaylists(
        _authService.accessToken!,
        limit: 50,
      );
      if (!mounted) return;
      final items = (data?['items'] ?? []) as List<dynamic>;
      _userPlaylists = items.map((e) => _parsePlaylist(e)).toList();
      setStateIfMounted(() {
        _isLoading = false;
        _currentView = _SwitcherView.spotifyPlaylists;
      });
    } catch (e, st) {
      _logger.e('fetchUserPlaylists error', error: e, stackTrace: st);
      _setError(
          'Could not load your playlists.', _LastFailedAction.fetchPlaylists);
    }
  }

  Future<void> _fetchPlaylistTracks(
    SpotifyPlaylistSimple playlist, {
    bool forceRefresh = false,
  }) async {
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error fetching tracks.',
          _LastFailedAction.fetchTracks);
      return;
    }
    _selectedPlaylistForTracksView = playlist;
    if (_playlistTracksCache.containsKey(playlist.id) && !forceRefresh) {
      setStateIfMounted(
          () => _currentView = _SwitcherView.spotifyPlaylistTracks);
      return;
    }
    _setLoading(true, message: 'Loading tracks for "${playlist.name}"...');
    try {
      final data = await _apiService.getPlaylistTracks(
        _authService.accessToken!,
        playlist.id,
        limit: 100,
      );
      if (!mounted) return;
      final items = (data?['items'] ?? []) as List<dynamic>;
      final tracks = items
          .map((e) => _parseTrack(e))
          .whereType<SpotifyTrackSimple>()
          .toList();
      _playlistTracksCache[playlist.id] = tracks;
      setStateIfMounted(() {
        _isLoading = false;
        _currentView = _SwitcherView.spotifyPlaylistTracks;
      });
    } catch (e, st) {
      _logger.e('fetchPlaylistTracks error', error: e, stackTrace: st);
      _setError('Could not load tracks for "${playlist.name}".',
          _LastFailedAction.fetchTracks);
    }
  }

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
        track['is_local'] == true) return null;

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

  void _retryLastAction() {
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
        if (_authService.isAuthenticated) {
          _fetchUserPlaylists(forceRefresh: true);
        } else {
          setStateIfMounted(() => _currentView = _SwitcherView.selection);
        }
        break;
    }
  }

  // ---------------------------------------------------------------------------
  //  UI actions
  // ---------------------------------------------------------------------------

  void _handleSpotifyLoginTap() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.green[700]),
          const SizedBox(width: 10),
          Text('Spotify Login',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Login is required to access your Spotify playlists and control playback.',
          style: GoogleFonts.inter(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _setLoading(true, message: 'Redirecting to Spotify...');
              _authService.login();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Connect Spotify',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleViewPlaylistsTap() {
    final playback = context.read<SpotifyPlaybackProvider>();

    if (playback.playerStatus == PlayerConnectionStatus.connected ||
        _userPlaylists != null) {
      setStateIfMounted(() => _currentView = _SwitcherView.spotifyPlaylists);
      if (_userPlaylists == null) _fetchUserPlaylists();
    } else if (playback.playerStatus == PlayerConnectionStatus.error ||
        playback.playerStatus == PlayerConnectionStatus.disconnected) {
      _handleRetryPlayerConnection();
    } else if (playback.playerStatus == PlayerConnectionStatus.none &&
        _authService.isAuthenticated &&
        _authService.accessToken != null) {
      _handleRetryPlayerConnection();
    }
  }

  // ---------------------------------------------------------------------------
  //  Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
        topLeft: Radius.circular(40), topRight: Radius.circular(40));

    return Consumer<SpotifyAuthService>(
      builder: (context, authService, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (_isLoading &&
              _loadingMessage.contains('Redirecting') &&
              authService.isAuthenticated) {
            _onAuthSuccess();
          } else if ((_currentView == _SwitcherView.spotifyPlaylists ||
                  _currentView == _SwitcherView.spotifyPlaylistTracks) &&
              !authService.isAuthenticated) {
            _clearSpotifyData(clearSelection: true);
          }
        });

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through
              child: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.75,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300.withOpacity(0.6),
                        borderRadius: borderRadius,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          color: Colors.white.withOpacity(0.95),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (c, anim) =>
                              FadeTransition(opacity: anim, child: c),
                          child: _buildCurrentView(authService),
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

  Widget _buildCurrentView(SpotifyAuthService auth) {
    final playback = context.watch<SpotifyPlaybackProvider>();
    final selectedSource =
        context.watch<AudioSourceSelectionProvider>().currentSource;

    if (_isLoading && _currentView == _SwitcherView.spotifyLoading) {
      return LoadingView(
          key: const ValueKey('loading'), message: _loadingMessage);
    }
    if (_currentView == _SwitcherView.spotifyError &&
        _spotifyErrorMsg.isNotEmpty) {
      return ErrorView(
        key: ValueKey('error_$_spotifyErrorMsg'),
        errorMessage: _spotifyErrorMsg,
        canRetry: _lastFailedAction != _LastFailedAction.none,
        onRetry: _retryLastAction,
        onGoBack: () {
          _clearSpotifyData(keepUserPlaylists: true);
          setStateIfMounted(() => _currentView = _SwitcherView.selection);
        },
      );
    }

    switch (_currentView) {
      case _SwitcherView.selection:
        return SourceSelectionView(
          key: const ValueKey('selection'),
          selectedSource: selectedSource,
          isSpotifyAuthenticated: auth.isAuthenticated,
          isSpotifyPlayerConnecting:
              playback.playerStatus == PlayerConnectionStatus.connecting,
          isSpotifyPlayerConnected:
              playback.playerStatus == PlayerConnectionStatus.connected,
          isSpotifyPlayerDisconnected:
              playback.playerStatus == PlayerConnectionStatus.disconnected,
          isSpotifyPlayerError:
              playback.playerStatus == PlayerConnectionStatus.error,
          spotifyPlayerErrorMessage: playback.playerConnectionErrorMsg,
          onClosePanel: widget.onClose,
          onSelectSource: _selectSource,
          onSpotifyLoginTap: _handleSpotifyLoginTap,
          onSpotifyLogout: _logoutSpotify,
          onViewPlaylistsTap: _handleViewPlaylistsTap,
          onRetryPlayerConnection: _handleRetryPlayerConnection,
          currentPlayingTrack: playback.currentSpotifyTrackDetails,
          isSdkPlayerPaused: playback.isPaused,
          onToggleSdkPlayerPlayback: _toggleSdkPlayerPlayback,
        );

      case _SwitcherView.spotifyPlaylists:
        return SpotifyPlaylistView(
          key: const ValueKey('playlists'),
          playlists: _userPlaylists,
          isLoading: _isLoading,
          onBack: () =>
              setStateIfMounted(() => _currentView = _SwitcherView.selection),
          onClosePanel: widget.onClose,
          onRefresh: () => _fetchUserPlaylists(forceRefresh: true),
          onPlaylistTap: _fetchPlaylistTracks,
        );

      case _SwitcherView.spotifyPlaylistTracks:
        if (_selectedPlaylistForTracksView == null) {
          return ErrorView(
            key: const ValueKey('no_playlist'),
            errorMessage: 'No playlist selected.',
            canRetry: false,
            onRetry: () {},
            onGoBack: () => setStateIfMounted(
                () => _currentView = _SwitcherView.spotifyPlaylists),
          );
        }
        return SpotifyTracksView(
          key: ValueKey('tracks_${_selectedPlaylistForTracksView!.id}'),
          playlist: _selectedPlaylistForTracksView!,
          tracks: _playlistTracksCache[_selectedPlaylistForTracksView!.id],
          isLoading: _isLoading,
          currentlyPlayingUri: playback.currentlyPlayingUri,
          isSdkPlayerPaused: playback.isPaused,
          onBack: () => setStateIfMounted(
              () => _currentView = _SwitcherView.spotifyPlaylists),
          onClosePanel: widget.onClose,
          onRefresh: () => _fetchPlaylistTracks(_selectedPlaylistForTracksView!,
              forceRefresh: true),
          onTrackTapPlay: _startPlayback,
          onToggleCurrentTrackPlayback: _toggleSdkPlayerPlayback,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
