import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/display_track_notifier.dart';
import 'package:studybeats/studyroom/audio/lofi_controller.dart';
import 'package:studybeats/studyroom/audio/spotify_controller.dart';
import 'package:studybeats/studyroom/audio/audio_controller.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/playlist_controls.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/songinfo.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/volume.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/audio_source_switcher.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/background_sounds.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:studybeats/studyroom/playlist_notifier.dart';
import 'package:studybeats/studyroom/side_tiles/date_time_widget.dart';
import 'audio_widgets/controls/music_controls.dart';

const double kControlBarHeight = 80.0;

class PlayerWidget extends StatefulWidget {
  const PlayerWidget({
    required this.playlistId,
    required this.onLoaded,
    super.key,
  });

  final int playlistId;
  final VoidCallback onLoaded;

  @override
  State<PlayerWidget> createState() => PlayerWidgetState();
}

class PlayerWidgetState extends State<PlayerWidget>
    with WidgetsBindingObserver {
  late final AudioSourceSelectionProvider _audioSourceProvider;
  late final LofiAudioController _lofiController;
  late final SpotifyPlaybackController _spotifyController;
  AbstractAudioController? _currentAudioController;
  AudioSourceType _currentAudioSource = AudioSourceType.lofi;
  StreamSubscription? _spotifyStatusSubscription;
  // Fires whenever SpotifyPlaybackController’s display state (current track, etc.) changes.
  StreamSubscription? _spotifyDisplayStateSubscription;
  StreamSubscription? _spotifyErrorSubscription;
  StreamSubscription<PositionData>? _positionSubscription;
  StreamSubscription<bool>? _lofiPlayingSubscription;
  StreamSubscription<int?>? _lofiIndexSubscription;

  late final PlaylistNotifier _playlistNotifier;
  int? _lastPlaylistId;

  final _logger = getLogger('PlayerWidgetState');

  DisplayTrackInfo? currentSongInfo;
  List<DisplayTrackInfo> songQueue = [];
  //final SongCloudInfoService _songCloudInfoService = SongCloudInfoService();

  bool verticalLayout = false;
  bool _showQueue = false;
  bool _showEqualizer = false;
  bool _showBackgroundSound = false;
  bool _showAudioSource = false;

  bool _isCurrentSongFavorite = false;
  final _authService = AuthService();
  bool _audioPlayerError = false;

  int _streakCount = 0;

  final GlobalKey<IconControlsState> _iconControlsKey =
      GlobalKey<IconControlsState>();

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing PlayerWidget for playlistId ${widget.playlistId}');
    _lofiController = LofiAudioController(
      playlistId: widget.playlistId,
      onError: _showError,
    );

    _spotifyController = SpotifyPlaybackController(
      authService: Provider.of<SpotifyAuthService>(context, listen: false),
      apiService: SpotifyApiService(),
    );

    _audioSourceProvider =
        Provider.of<AudioSourceSelectionProvider>(context, listen: false);

    _currentAudioSource = _audioSourceProvider.currentSource;
    _audioSourceProvider.addListener(_handleAudioSourceChange);

    // Listen to playlist changes so we can stop playback immediately
    _playlistNotifier = Provider.of<PlaylistNotifier>(context, listen: false);
    _lastPlaylistId = _playlistNotifier.playlistId;
    _playlistNotifier.addListener(stopAll);

    _setActiveController(_currentAudioSource); // Set initial controller

    _updateSongState();
    _loadStreak();
  }

  void _loadStreak() async {
    try {
      final isAnonymous = await _authService.isUserAnonymous();
      if (!isAnonymous) {
        final count = await _authService.getStreakLength();
        if (mounted) setState(() => _streakCount = count);
      }
    } catch (e) {
      _logger.e('Failed to load streak count: $e');
    }
  }

  // Listener for Lofi controller's isLoaded state
  void _handleLofiLoaded() {
    _logger.d('Lofi controller reported isLoaded = true');
    if (_lofiController.isLoaded.value &&
        mounted &&
        _currentAudioSource == AudioSourceType.lofi) {
      _updateSongState();
    }
  }

  void _handleAudioSourceChange() {
    final newSource = _audioSourceProvider.currentSource;
    _logger.i('Audio source changed: $_currentAudioSource → $newSource');
    if (newSource != _currentAudioSource) {
      // Clean up listeners and stop the outgoing controller
      if (_currentAudioSource == AudioSourceType.lofi) {
        _lofiController.isLoaded.removeListener(_handleLofiLoaded);
        _lofiPlayingSubscription?.cancel();
        _lofiPlayingSubscription = null;
        _lofiIndexSubscription?.cancel();
        _lofiIndexSubscription = null;
      } else if (_currentAudioSource == AudioSourceType.spotify) {
        _spotifyStatusSubscription?.cancel();
        _spotifyStatusSubscription = null;
        _spotifyDisplayStateSubscription?.cancel();
        _spotifyDisplayStateSubscription = null;
        _spotifyErrorSubscription?.cancel();
        _spotifyErrorSubscription = null;
      }
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _currentAudioController?.stop();

      // Set new source and controller
      setState(() {
        _currentAudioSource = newSource;
        _audioPlayerError = false;
        currentSongInfo = null;
        context.read<DisplayTrackNotifier>().updateTrack(currentSongInfo);
        songQueue = [];
      });
      _setActiveController(newSource);
      _updateSongState();
    }
  }

  void _setActiveController(AudioSourceType source) {
    _logger.i('Switching to audio source: $source');
    // Defensive removal of any existing listeners before setting new ones
    _lofiController.isLoaded.removeListener(_handleLofiLoaded);
    _lofiPlayingSubscription?.cancel();
    _lofiPlayingSubscription = null;
    _lofiIndexSubscription?.cancel();
    _lofiIndexSubscription = null;
    _spotifyStatusSubscription?.cancel();
    _spotifyStatusSubscription = null;
    _spotifyDisplayStateSubscription?.cancel();
    _spotifyDisplayStateSubscription = null;
    _spotifyErrorSubscription?.cancel();
    _spotifyErrorSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (source == AudioSourceType.lofi) {
      _logger.d('Using LofiAudioController');
      _currentAudioController = _lofiController;
      if (_lofiController.isLoaded.value) {
        // Already initialised; just update state and attach listeners.
        _lofiController.isLoaded.addListener(_handleLofiLoaded);
        _lofiPlayingSubscription =
            _lofiController.isPlayingStream.listen((_) => _updateSongState());
        _lofiIndexSubscription = _lofiController.audioPlayer.currentIndexStream
            .listen((_) => _updateSongState());
        if (mounted) _updateSongState();
        return;
      }
      _lofiController.init().then((_) {
        _lofiController.isLoaded.addListener(_handleLofiLoaded); // Add listener
        // Update UI whenever play/pause changes
        _lofiPlayingSubscription = _lofiController.isPlayingStream.listen((_) {
          if (mounted && _currentAudioSource == AudioSourceType.lofi) {
            _updateSongState();
          }
        });
        // Update UI whenever current track index changes (first load included)
        _lofiIndexSubscription =
            _lofiController.audioPlayer.currentIndexStream.listen((_) {
          if (mounted && _currentAudioSource == AudioSourceType.lofi) {
            _updateSongState();
          }
        });
        _logger.i('LofiAudioController initialized');
        if (mounted) _updateSongState(); // initial song info
      }).catchError((e) {
        _logger.e('Failed to initialize Lofi player: $e');
        _showError('Failed to initialize Lofi player.');
        if (mounted) setState(() => _audioPlayerError = true);
      });
    } else if (source == AudioSourceType.spotify) {
      _logger.d('Using SpotifyPlaybackController');
      _currentAudioController = _spotifyController;
      _spotifyController.init().then((_) {
        _spotifyStatusSubscription =
            _spotifyController.isPlayingStream.listen((_) {
          if (mounted && _currentAudioSource == AudioSourceType.spotify) {
            _updateSongState();
          }
        });
        _spotifyDisplayStateSubscription =
            _spotifyController.displayStateStream.listen((_) {
          if (mounted && _currentAudioSource == AudioSourceType.spotify) {
            _updateSongState();
          }
        });
        _spotifyErrorSubscription =
            _spotifyController.errorStream.listen((msg) {
          if (mounted && _currentAudioSource == AudioSourceType.spotify) {
            _showError(msg);
            setState(() => _audioPlayerError = true);
          }
        });
        _logger.i('SpotifyPlaybackController initialized');
        if (mounted) _updateSongState(); // Initial update
      }).catchError((e) {
        _logger.e('Failed to initialize Spotify player: $e');
        _showError('Failed to initialize Spotify player.');
        if (mounted) setState(() => _audioPlayerError = true);
      });
    }
    if (mounted) setState(() {}); // Rebuild if necessary
  }

  void closeAllWidgets() {
    setState(() {
      _showQueue = false;
      _showEqualizer = false;
      _showBackgroundSound = false;
      _showAudioSource = false;
    });
    _iconControlsKey.currentState!.closeAll();
  }

  void _showError(
      [String message = 'Something went wrong. Please try again later.']) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    });
  }

  void stopAll() async {
    _logger.w('Stopping all audio sources');
    try {
      // Pause whatever is currently active
      await _currentAudioController?.pause();

      // Pause Lofi outright
      await _lofiController.pause();

      // Fully dispose the Spotify SDK player so playback halts no matter what
      await _spotifyController.disposePlayer();
    } catch (_) {
      _logger.e('Error during stopAll: $_');
      // Swallow errors during teardown – widget might be unmounted
    }
  }

  @override
  void dispose() {
    stopAll();
    // Remove listener for AudioSourceSelectionProvider
    _audioSourceProvider.removeListener(_handleAudioSourceChange);

    // Remove listener for Lofi controller
    _lofiController.isLoaded.removeListener(_handleLofiLoaded);
    _lofiIndexSubscription?.cancel();
    _lofiPlayingSubscription?.cancel();

    // Cancel Spotify stream subscription
    _spotifyStatusSubscription?.cancel();
    _spotifyDisplayStateSubscription?.cancel();
    _spotifyErrorSubscription?.cancel();
    _positionSubscription?.cancel();

    _lofiController.dispose();
    _spotifyController.dispose();
    super.dispose();
  }

  Future<void> _updateSongState() async {
    _logger.d('Updating song state for $_currentAudioSource');
    if (_currentAudioController == null) {
      _logger.w('No active audio controller');
      return;
    }

    final newSongInfo = _currentAudioController!.currentDisplayTrackInfo;
    if (newSongInfo == null &&
        _currentAudioSource == AudioSourceType.lofi &&
        !_lofiController.isLoaded.value) {
      _logger.w('SongInfo null but Lofi not loaded yet — will retry.');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _lofiController.isLoaded.value) {
          _logger.i('Retrying _updateSongState after delay (lofi ready).');
          _updateSongState();
        }
      });
      return;
    }
    bool newIsFavorite = false;
    List<DisplayTrackInfo> newSongQueue = [];

    if (_currentAudioSource == AudioSourceType.lofi) {
      final lofiSongInfo = _lofiController.getCurrentSongInfo();
      if (lofiSongInfo != null) {
        //newIsFavorite = await _songCloudInfoService.isSongFavorite(
        //  widget.playlistId, lofiSongInfo);
      }
      newSongQueue = _lofiController.getSongOrder();
    } else if (_currentAudioSource == AudioSourceType.spotify) {
      newIsFavorite = false;
      newSongQueue = [];
    }

    _logger.v('New song: ${newSongInfo?.trackName}, favorite: $newIsFavorite');
    if (!mounted) return;
    setState(() {
      currentSongInfo = newSongInfo;
      context.read<DisplayTrackNotifier>().updateTrack(currentSongInfo);
      _isCurrentSongFavorite = newIsFavorite;
      songQueue = newSongQueue;
      _audioPlayerError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAudioController == null || _audioPlayerError) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: kControlBarHeight,
            width: MediaQuery.of(context).size.width,
            color: Colors.white,
          ),
        ),
      );
    }
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (_showQueue ||
                    _showEqualizer ||
                    _showBackgroundSound ||
                    _showAudioSource)
                  const Spacer(),
                /*
                if (_currentAudioSource == AudioSourceType.lofi && _showQueue)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SongQueue(
                        songOrder: _lofiController.audioPlayer.sequence
                                ?.map((audioSource) =>
                                    audioSource.tag as LofiSongMetadata)
                                .toList()
                                .isEmpty ?? true
                            ? null
                            : _lofiController.audioPlayer.sequence!
                                .map((audioSource) =>
                                    audioSource.tag as LofiSongMetadata)
                                .toList(),
                        currentSong: currentSongInfo,
                        queue: songQueue.isEmpty ? null : songQueue,
                        onSongSelected: (index) async {
                          await _lofiController.play();
                          _lofiController.seekToIndex(index).then((_) {
                            _updateSongState();
                          });
                        },
                      ),
                    ),
                  )
                  */

                Visibility(
                  visible: _showAudioSource,
                  maintainState: true,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: AudioSourceSwitcher(
                        initialAudioSource: _currentAudioSource,
                        lofiController: _lofiController,
                        onAudioSourceChanged: (source) {},
                        spotifyController: _spotifyController, // Pass instance
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: _showBackgroundSound &&
                      _currentAudioSource == AudioSourceType.lofi,
                  maintainState: true,
                  child: StreamBuilder<PositionData>(
                      stream: _currentAudioController?.positionDataStream ??
                          Stream.value(PositionData(
                              Duration.zero, Duration.zero, Duration.zero)),
                      builder: (context, snapshot) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: const BackgroundSfxControls(),
                        );
                      }),
                )
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: verticalLayout ? 300 : 80,
                child: Stack(
                  children: [
                    buildBackdrop(),
                    buildControls(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildBackdrop() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget buildControls() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Scrollbar(
        thumbVisibility: false, // Set to false for auto-hide on scroll
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: _buildResponsiveControls(context),
          ),
        ),
      ),
    );
  }

  /// Always shows all control bar widgets, regardless of width.
  List<Widget> _buildResponsiveControls(BuildContext context) {
    final List<Widget> widgets = [];

    void addSpacer() => widgets.add(const SizedBox(width: 12));

    widgets.add(const SizedBox(width: 150));

    // Always show primary playback controls
    widgets.add(
      StreamBuilder<bool>(
        stream: _currentAudioController?.isPlayingStream ?? Stream.value(false),
        builder: (context, snapshot) {
          final playing = snapshot.data ?? false;
          return Controls(
            showFavorite: false,
            showShuffle: _currentAudioSource == AudioSourceType.lofi,
            onShuffle: _shuffle,
            onPrevious: () => currentSongInfo != null ? _previousSong() : null,
            onPlay: () => currentSongInfo != null ? _play() : null,
            onPause: () => currentSongInfo != null ? _pause() : null,
            onNext: () => currentSongInfo != null ? _nextSong() : null,
            onFavorite: (value) async {
              if (_currentAudioSource == AudioSourceType.lofi) {
                final isAnonymous = await _authService.isUserAnonymous();
                !isAnonymous
                    ? _toggleFavorite(value)
                    : context.goNamed(AppRoute.loginPage.name);
              }
            },
            isPlaying: playing,
            isFavorite: _currentAudioSource == AudioSourceType.lofi
                ? _isCurrentSongFavorite
                : false,
          );
        },
      ),
    );

    // Always show SongInfo
    addSpacer();
    widgets.add(
      SongInfo(
        song: currentSongInfo,
        positionStream: _currentAudioController?.positionDataStream ??
            Stream.value(
                PositionData(Duration.zero, Duration.zero, Duration.zero)),
        onSeekRequested: (newPosition) {
          try {
            _currentAudioController?.seek(newPosition);
          } catch (e) {
            _showError("Failed to seek track. Please try again.");
          }
        },
      ),
    );

    // Always show VolumeSlider
    addSpacer();
    widgets.add(
      VolumeSlider(
        volumeChanged: (volume) {
          try {
            _currentAudioController?.setVolume(volume);
          } catch (e) {
            _showError("Failed to set volume. Please try again.");
          }
        },
      ),
    );

    // Always show auxiliary icon controls
    addSpacer();
    widgets.add(
      IconControls(
        key: _iconControlsKey,
        onAudioSourcePressed: (enabled) {
          setState(() => _showAudioSource = enabled);
        },
        onBackgroundSoundPressed: (enabled) {
          setState(() => _showBackgroundSound = enabled);
        },
      ),
    );

    // Always show daily‑streak badge (if any)
    addSpacer();

    widgets.add(StreakWidget(streakCount: _streakCount));

    // Always show date/time widget
    addSpacer();
    widgets.add(DateTimeWidget());

    return widgets;
  }

  ///
  /// Make sure to check if user is anonymous before toggling favorite
  void _toggleFavorite(bool isFavorite) async {
    if (_currentAudioSource != AudioSourceType.lofi ||
        currentSongInfo == null) {
      return;
    }

    final lofiSongInfoForFavorite = _lofiController.getCurrentSongInfo();
    if (lofiSongInfoForFavorite == null) return;

    setState(() => _isCurrentSongFavorite = isFavorite);
    try {
      //await _songCloudInfoService.markSongFavorite(
      //  widget.playlistId, lofiSongInfoForFavorite, isFavorite);
    } catch (e) {
      if (mounted) {
        setState(() => _isCurrentSongFavorite = !isFavorite);
        _showError('Could not update favorite status.');
      }
    }
  }

  void _play() async {
    try {
      await _currentAudioController?.play();
    } catch (e) {
      _showError("Failed to play track.");
    }
  }

  void _pause() async {
    try {
      await _currentAudioController?.pause();
    } catch (e) {
      _showError("Failed to pause track.");
    }
  }

  void _shuffle() async {
    try {
      await _currentAudioController?.shuffle();
      _updateSongState();
    } catch (e) {
      _showError("Failed to toggle shuffle.");
    }
  }

  void _nextSong() async {
    try {
      await _currentAudioController?.next();
      _updateSongState();
    } catch (e) {
      _showError('Could not play next song.');
    }
  }

  void _previousSong() async {
    try {
      await _currentAudioController?.previous();
      _updateSongState();
    } catch (e) {
      _showError('Could not play previous song.');
    }
  }
}

class StreakWidget extends StatefulWidget {
  final int streakCount;

  const StreakWidget({super.key, required this.streakCount});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> {
  bool _isAnonymous = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() async {
    try {
      final isAnonymous = await AuthService().isUserAnonymous();
      if (mounted) {
        setState(() {
          _isAnonymous = isAnonymous;
        });
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnonymous || widget.streakCount <= 0) {
      return const SizedBox.shrink(); // Don't show if anonymous or no streak
    }
    return Tooltip(
      message:
          'You’ve used Studybeats ${widget.streakCount} day${widget.streakCount == 1 ? '' : 's'} in a row!',
      textStyle: const TextStyle(color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              '${widget.streakCount}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
