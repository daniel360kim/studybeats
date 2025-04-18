import 'dart:ui';
import 'package:studybeats/api/audio/cloud_info/cloud_info_service.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/audio/audio.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/playlist_controls.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/songinfo.dart';
import 'package:studybeats/studyroom/audio_widgets/controls/volume.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/background_sounds.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/equalizer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/queue.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'audio_widgets/controls/music_controls.dart';

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
  late final Audio _audio;
  SongMetadata? currentSongInfo;
  List<SongMetadata> songQueue = [];
  List<SongMetadata> songOrder = [];
  final SongCloudInfoService _songCloudInfoService = SongCloudInfoService();

  bool verticalLayout = false;
  bool _showQueue = false;
  bool _showEqualizer = false;
  bool _showBackgroundSound = false;

  bool _isCurrentSongFavorite = false;
  final _authService = AuthService();
  bool _audioPlayerError = false;

  final GlobalKey<IconControlsState> _iconControlsKey =
      GlobalKey<IconControlsState>();

  @override
  void initState() {
    super.initState();
    _audio = Audio(
      playlistId: widget.playlistId,
      onError: _showError,
    );
    initAudio();

    _audio.isLoaded.addListener(() {
      if (_audio.isLoaded.value) {
        updateSong();
      }
    });
  }

  void initAudio() async {
    try {
      await _audio.initPlayer();
      await _songCloudInfoService.init();
    } catch (e) {
      if (mounted) _showError();
      setState(() {
        _audioPlayerError = true;
      });
    }
    updateSong();
  }

  void closeAllWidgets() {
    setState(() {
      _showQueue = false;
      _showEqualizer = false;
      _showBackgroundSound = false;
    });
    _iconControlsKey.currentState!.closeAll();
  }

  void _showError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again later'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> updateSong() async {
    final songInfo = _audio.getCurrentSongInfo();
    if (songInfo == null) return;
    final isCurrentSongFavorite =
        await _songCloudInfoService.isSongFavorite(widget.playlistId, songInfo);
    setState(() {
      currentSongInfo = songInfo;
      _isCurrentSongFavorite = isCurrentSongFavorite;
      songQueue = _audio.getSongOrder();
      songOrder = _audio.getSongOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_audioPlayerError) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 80,
            width: MediaQuery.of(context).size.width,
            color: Colors.white,
          ),
        ),
      );
    }
    return Stack(
      children: [
        // PlayerWidget content is placed above the barrier.
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Top row for sub-widgets.
            // Wrap in a detector to absorb taps.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (_showQueue || _showEqualizer || _showBackgroundSound)
                  const Spacer(),
                _showQueue
                    ? Align(
                        alignment: Alignment.bottomRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: SongQueue(
                            songOrder: _audio.audioPlayer.sequence!
                                    .map((audioSource) =>
                                        audioSource.tag as SongMetadata)
                                    .toList()
                                    .isEmpty
                                ? null
                                : _audio.audioPlayer.sequence!
                                    .map((audioSource) =>
                                        audioSource.tag as SongMetadata)
                                    .toList(),
                            currentSong: currentSongInfo,
                            queue: songQueue.isEmpty ? null : songQueue,
                            onSongSelected: (index) async {
                              await _audio.play();
                              _audio.seekToIndex(index).then((_) {
                                updateSong();
                              });
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                _showEqualizer
                    ? Align(
                        alignment: Alignment.bottomRight,
                        child: StreamBuilder<PositionData>(
                            stream: _audio.positionDataStream,
                            builder: (context, snapshot) {
                              final elapsedDuration =
                                  snapshot.data?.position ?? Duration.zero;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {},
                                child: EqualizerControls(
                                  song: currentSongInfo,
                                  elapsedDuration: elapsedDuration,
                                  onSpeedChange: (value) =>
                                      _audio.setSpeed(value),
                                ),
                              );
                            }),
                      )
                    : const SizedBox.shrink(),
                Visibility(
                  visible: _showBackgroundSound,
                  maintainState: true,
                  child: StreamBuilder<PositionData>(
                      stream: _audio.positionDataStream,
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
            // Main controls area.
            // Wrap with detector to absorb taps inside controls.
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
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 1050) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buildControlWidgets(),
          );
        } else if (constraints.maxWidth < 1050 && constraints.maxWidth > 850) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buildControlWidgets().sublist(0, 3),
          );
        } else if (constraints.maxWidth < 850 && constraints.maxWidth > 700) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buildControlWidgets().sublist(0, 2),
          );
        } else {
          return buildMiniControlWidgets();
        }
      }),
    );
  }

  Widget buildMiniControlWidgets() {
    return Center(
      child: StreamBuilder<PlayerState>(
        stream: _audio.audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final playing = playerState?.playing;
          if (playing != null) {
            return Controls(
              onShuffle: _audio.shuffle,
              onPrevious: _previousSong,
              onPlay: _audio.play,
              onPause: _audio.pause,
              onNext: _nextSong,
              onFavorite: (value) {
                _authService.isUserLoggedIn()
                    ? _toggleFavorite(value)
                    : context.goNamed(AppRoute.loginPage.name);
              },
              isPlaying: playing,
              isFavorite: _isCurrentSongFavorite,
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  List<Widget> buildControlWidgets() {
    return [
      StreamBuilder<PlayerState>(
        stream: _audio.audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final playing = playerState?.playing;
          if (playing != null) {
            return Controls(
              onShuffle: () => _audio.shuffle(),
              onPrevious: _previousSong,
              onPlay: _audio.play,
              onPause: _audio.pause,
              onNext: _nextSong,
              onFavorite: (value) {
                _authService.isUserLoggedIn()
                    ? _toggleFavorite(value)
                    : context.goNamed(AppRoute.loginPage.name);
              },
              isPlaying: playing,
              isFavorite: _isCurrentSongFavorite,
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
      SongInfo(
        song: currentSongInfo,
        positionData: _audio.positionDataStream,
        onSeekRequested: (newPosition) => _audio.seek(newPosition),
      ),
      VolumeSlider(
        volumeChanged: (volume) => _audio.setVolume(volume),
      ),
      IconControls(
        key: _iconControlsKey,
        onListPressed: (enabled) {
          setState(() {
            // Uncomment if list functionality is needed.
            //_showQueue = enabled;
          });
        },
        onEqualizerPressed: (enabled) {
          setState(() {
            _showEqualizer = enabled;
          });
        },
        onBackgroundSoundPressed: (enabled) {
          setState(() {
            _showBackgroundSound = enabled;
          });
        },
      ),
    ];
  }

  void _toggleFavorite(bool isFavorite) async {
    if (!_authService.isUserLoggedIn()) return;
    setState(() => _isCurrentSongFavorite = isFavorite);
    try {
      await _songCloudInfoService.markSongFavorite(
          widget.playlistId, currentSongInfo!, isFavorite);
    } catch (e) {
      setState(() => _isCurrentSongFavorite = !isFavorite);
    }
  }

  void _nextSong() async {
    setState(() {
      currentSongInfo = _audio.getNextSongInfo();
    });
    try {
      await _audio.nextSong();
    } catch (e) {
      // Handle error as needed.
    }
  }

  void _previousSong() async {
    setState(() {
      currentSongInfo = _audio.getPreviousSongInfo();
    });
    try {
      await _audio.previousSong();
    } catch (e) {
      // Handle error as needed.
    }
  }
}
