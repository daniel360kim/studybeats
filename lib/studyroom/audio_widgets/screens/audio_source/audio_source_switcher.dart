import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter.blur
import 'dart:async'; // StreamSubscription
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
import 'package:studybeats/studyroom/audio/spotify_controller.dart';
import 'package:url_launcher/url_launcher.dart';

// Views
import 'views/source_selection_view.dart';
import 'views/spotify_playlist_view.dart';
import 'views/spotify_tracks_view.dart'; // For SpotifyTracksView.spotifyGreen
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

// Tracks the last failed async action
enum _LastFailedAction { none, fetchPlaylists, fetchTracks }

class AudioSourceSwitcher extends StatefulWidget {
  final AudioSourceType initialAudioSource;
  final ValueChanged<AudioSourceType> onAudioSourceChanged;
  final VoidCallback? onClose;
  final SpotifyPlaybackController spotifyController;

  const AudioSourceSwitcher({
    super.key,
    required this.initialAudioSource,
    required this.onAudioSourceChanged,
    this.onClose,
    required this.spotifyController,
  });

  @override
  State<AudioSourceSwitcher> createState() => _AudioSourceSwitcherState();
}

class _AudioSourceSwitcherState extends State<AudioSourceSwitcher> {
  _SwitcherView _currentView = _SwitcherView.selection;

  // Spotify state
  SpotifyPlaylistSimple? _selectedPlaylistForTracksView;

  // Loading & error state
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';
  String _spotifyErrorMsg = '';
  _LastFailedAction _lastFailedAction = _LastFailedAction.none;

  // Services & logger
  late SpotifyAuthService _authService; // set in didChangeDependencies
  final _logger = getLogger('AudioSourceSwitcher');

  // Local player-display subscription
  SpotifyPlayerDisplayState _spotifyPlayerDisplayState =
      SpotifyPlayerDisplayState.initial();
  StreamSubscription? _spotifyDisplayStateSubscription;
  StreamSubscription? _spotifyErrorSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AudioSourceSelectionProvider>()
          .setSource(widget.initialAudioSource);
    });

    _spotifyDisplayStateSubscription =
        widget.spotifyController.displayStateStream.listen((newState) {
      if (mounted) {
        setState(() => _spotifyPlayerDisplayState = newState);
      }
    });
    _spotifyErrorSub = widget.spotifyController.errorStream.listen((msg) {
      if (mounted) {
        _setError(msg, _LastFailedAction.none);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<SpotifyAuthService>(context, listen: false);
  }

  @override
  void dispose() {
    _spotifyDisplayStateSubscription?.cancel();
    _spotifyErrorSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  Helpers
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
  //  Controller-backed actions
  // ---------------------------------------------------------------------------

  Future<void> _startPlayback(String trackUri) async {
    try {
      await widget.spotifyController.playTrack(
        trackUri,
        contextTracks: _selectedPlaylistForTracksView != null
            ? widget.spotifyController
                .getCachedPlaylistTracks(_selectedPlaylistForTracksView!.id)
            : null,
      );
    } catch (e) {
      _setError("Playback error. Please try again.", _LastFailedAction.none);
    }
  }

  void _toggleSdkPlayerPlayback() {
    try {
      widget.spotifyController.togglePlayPause();
    } catch (e) {
      _setError("Could not toggle play/pause.", _LastFailedAction.none);
    }
  }

  void _handleRetryPlayerConnection() {
    try {
      widget.spotifyController.initializePlayer();
    } catch (e) {
      _setError("Retrying connection failed.", _LastFailedAction.none);
    }
  }

  void _onAuthSuccess() {
    try {
      widget.spotifyController.initializePlayer();
      _fetchUserPlaylists();
    } catch (e) {
      _setError("Post-login setup failed.", _LastFailedAction.none);
    }
  }

  void _logoutSpotify() {
    try {
      widget.spotifyController.disposePlayer();
      _authService.logout();
    } catch (e) {
      _setError("Logout failed.", _LastFailedAction.none);
    }
  }

  // ---------------------------------------------------------------------------
  //  Spotify library helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchUserPlaylists({bool forceRefresh = false}) async {
    if (!(_authService.isAuthenticated && _authService.accessToken != null)) {
      _setError('Authentication error. Please login again.',
          _LastFailedAction.fetchPlaylists);
      return;
    }

    if (widget.spotifyController.cachedUserPlaylists != null && !forceRefresh) {
      setStateIfMounted(() => _currentView = _SwitcherView.spotifyPlaylists);
      return;
    }

    _setLoading(true, message: 'Loading your playlists...');
    final playlists = await widget.spotifyController
        .fetchUserPlaylists(forceRefresh: forceRefresh);
    if (!mounted) return;

    if (playlists != null) {
      setStateIfMounted(() {
        _isLoading = false;
        _currentView = _SwitcherView.spotifyPlaylists;
      });
    } else {
      _setError(
          'Could not load your playlists.', _LastFailedAction.fetchPlaylists);
    }
  }

  Future<void> _fetchPlaylistTracks(
    SpotifyPlaylistSimple playlist, {
    bool forceRefresh = false,
  }) async {
    if (!(_authService.isAuthenticated && _authService.accessToken != null)) {
      _setError('Authentication error fetching tracks.',
          _LastFailedAction.fetchTracks);
      return;
    }
    _selectedPlaylistForTracksView = playlist;

    if (widget.spotifyController.getCachedPlaylistTracks(playlist.id) != null &&
        !forceRefresh) {
      setStateIfMounted(
          () => _currentView = _SwitcherView.spotifyPlaylistTracks);
      return;
    }

    _setLoading(true, message: 'Loading tracks for "${playlist.name}"...');
    final tracks = await widget.spotifyController.fetchPlaylistTracks(
      playlist.id,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;

    if (tracks != null) {
      setStateIfMounted(() {
        // Pre‑load queue so Next/Previous work even before first tap.
        widget.spotifyController
            .setQueue(tracks, startIndex: 0); // default to first track
        _isLoading = false;
        _currentView = _SwitcherView.spotifyPlaylistTracks;
      });
    } else {
      _setError('Could not load tracks for "${playlist.name}".',
          _LastFailedAction.fetchTracks);
    }
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
  //  Audio source selection
  // ---------------------------------------------------------------------------

  void _selectSource(AudioSourceType source) {
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

      if (_authService.isAuthenticated) {
        _handleRetryPlayerConnection();
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  UI taps
  // ---------------------------------------------------------------------------

  void _handleSpotifyLoginTap() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.info_outline_rounded,
              color: const Color(0xFF1DB954), // Changed to spotifyGreen
              ), // Changed to spotifyGreen
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
    final display = _spotifyPlayerDisplayState;

    if (display.playerStatus == PlayerConnectionStatus.connected ||
        widget.spotifyController.cachedUserPlaylists != null) {
      setStateIfMounted(() => _currentView = _SwitcherView.spotifyPlaylists);
      if (widget.spotifyController.cachedUserPlaylists == null) {
        _fetchUserPlaylists();
      }
    } else if (display.playerStatus == PlayerConnectionStatus.error ||
        display.playerStatus == PlayerConnectionStatus.disconnected) {
      _handleRetryPlayerConnection();
    } else if (display.playerStatus == PlayerConnectionStatus.none &&
        _authService.isAuthenticated) {
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
      builder: (context, authService, _) {
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
    final display = _spotifyPlayerDisplayState;
    final selectedSource =
        context.watch<AudioSourceSelectionProvider>().currentSource;

    if (_isLoading && _currentView == _SwitcherView.spotifyLoading) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: GestureDetector(
              onTap: () async {
                final Uri url = Uri.parse('https://www.spotify.com');
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  _logger.w("Could not launch Spotify URL");
                }
              },
              child: Image.asset(
                'assets/brand/spotify_logo_full_black.png', // Full logo (icon + wordmark)
                height:
                    24, // Ensure height maintains aspect ratio for >= 70px width
                fit: BoxFit.contain,
                semanticLabel: 'Powered by Spotify. Links to Spotify.com',
              ),
            ),
          ),
          Expanded(
            child: LoadingView(
              key: const ValueKey('loading'),
              message: _loadingMessage,
            ),
          ),
        ],
      );
    }

    if (_currentView == _SwitcherView.spotifyError &&
        _spotifyErrorMsg.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: GestureDetector(
              onTap: () async {
                final Uri url = Uri.parse('https://www.spotify.com');
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  _logger.w("Could not launch Spotify URL");
                }
              },
              child: Image.asset(
                'assets/brand/spotify_logo_full_black.png', // Full logo (icon + wordmark)
                height:
                    24, // Ensure height maintains aspect ratio for >= 70px width
                fit: BoxFit.contain,
                semanticLabel: 'Powered by Spotify. Links to Spotify.com',
              ),
            ),
          ),
          Expanded(
            child: ErrorView(
              key: ValueKey('error_$_spotifyErrorMsg'),
              errorMessage: _spotifyErrorMsg,
              canRetry: _lastFailedAction != _LastFailedAction.none,
              onRetry: _retryLastAction,
              onGoBack: () {
                _clearSpotifyData(keepUserPlaylists: true);
                setStateIfMounted(() => _currentView = _SwitcherView.selection);
              },
            ),
          ),
        ],
      );
    }

    switch (_currentView) {
      case _SwitcherView.selection:
        return SourceSelectionView(
          key: const ValueKey('selection'),
          selectedSource: selectedSource,
          isSpotifyAuthenticated: auth.isAuthenticated,
          isSpotifyPlayerConnecting:
              display.playerStatus == PlayerConnectionStatus.connecting,
          isSpotifyPlayerConnected:
              display.playerStatus == PlayerConnectionStatus.connected,
          isSpotifyPlayerDisconnected:
              display.playerStatus == PlayerConnectionStatus.disconnected,
          isSpotifyPlayerError:
              display.playerStatus == PlayerConnectionStatus.error,
          spotifyPlayerErrorMessage: display.errorMessage,
          onClosePanel: widget.onClose,
          onSelectSource: _selectSource,
          onSpotifyLoginTap: _handleSpotifyLoginTap,
          onSpotifyLogout: _logoutSpotify,
          onViewPlaylistsTap: _handleViewPlaylistsTap,
          onRetryPlayerConnection: _handleRetryPlayerConnection,
          currentPlayingTrack: display.currentTrack,
          isSdkPlayerPaused: display.isPaused,
          onToggleSdkPlayerPlayback: _toggleSdkPlayerPlayback,
        );

      case _SwitcherView.spotifyPlaylists:
        return SpotifyPlaylistView(
          key: const ValueKey('playlists'),
          playlists: widget.spotifyController.cachedUserPlaylists,
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
          tracks: widget.spotifyController
              .getCachedPlaylistTracks(_selectedPlaylistForTracksView!.id),
          isLoading: _isLoading,
          currentlyPlayingUri: display.currentlyPlayingUri,
          isSdkPlayerPaused: display.isPaused,
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
