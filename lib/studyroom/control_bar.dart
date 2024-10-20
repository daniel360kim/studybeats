import 'dart:ui';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/router.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/audio.dart';
import 'package:flourish_web/studyroom/audio/seekbar.dart';
import 'package:flourish_web/studyroom/widgets/controls/playlist_controls.dart';
import 'package:flourish_web/studyroom/widgets/controls/songinfo.dart';
import 'package:flourish_web/studyroom/widgets/controls/volume.dart';
import 'package:flourish_web/studyroom/widgets/screens/equalizer.dart';
import 'package:flourish_web/studyroom/widgets/screens/queue.dart';
import 'package:flourish_web/studyroom/widgets/screens/songcredits.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'widgets/controls/music_controls.dart';

class Player extends StatefulWidget {
  const Player({
    required this.playlistId,
    super.key,
  });

  final int playlistId;

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  late final Audio _audio;

  SongMetadata? currentSongInfo;
  List<SongMetadata> songQueue = [];
  List<SongMetadata> songOrder = [];

  SongCloudInfo currentCloudSongInfo = const SongCloudInfo(
    isFavorite: false,
    timesPlayed: 0,
    totalPlaytime: Duration.zero,
    averagePlaytime: Duration.zero,
  );

  bool verticalLayout = false;
  bool _showQueue = false;
  bool _showSongInfo = false;
  bool _showEqualizer = false;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _audio = Audio(playlistId: widget.playlistId);
    initAudio();

    _audio.isLoaded.addListener(() {
      if (_audio.isLoaded.value) {
        updateSong();
      }
    });
  }

  void initAudio() async {
    _audio.initPlayer();
    updateSong();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  void updateSong() async {
    setState(() {
      currentSongInfo = _audio.getCurrentSongInfo();
      songQueue = _audio.getSongOrder();
      songOrder = _audio.getSongOrder();
    });

    if (_authService.isUserLoggedIn()) {
      _audio.getCurrentSongCloudInfo().then((value) {
        setState(() {
          currentCloudSongInfo = value;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_audio.audioPlayer.sequence == null) {
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (_showQueue || _showSongInfo || _showEqualizer) const Spacer(),
              _showQueue
                  ? Align(
                      alignment: Alignment.bottomRight,
                      child: SongQueue(
                        songOrder: _audio.audioPlayer.sequence!
                                .map((audioSource) {
                                  return audioSource.tag as SongMetadata;
                                })
                                .toList()
                                .isEmpty
                            ? null
                            : _audio.audioPlayer.sequence!.map((audioSource) {
                                return audioSource.tag as SongMetadata;
                              }).toList(),
                        currentSong: currentSongInfo,
                        queue: songQueue.isEmpty ? null : songQueue,
                        onSongSelected: (index) {
                          _audio.play();
                          _audio.seekToIndex(index).then((value) {
                            updateSong();
                          });
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
              _showSongInfo
                  ? Align(
                      alignment: Alignment.bottomRight,
                      child: SongCredits(
                        song: currentSongInfo,
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
                            return EqualizerControls(
                              song: currentSongInfo,
                              elapsedDuration: elapsedDuration,
                              onSpeedChange: (value) => _audio.setSpeed(value),
                            );
                          }),
                    )
                  : const SizedBox.shrink(),
            ]),
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
    return LayoutBuilder(builder: (context, constraints) {
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
    });
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
              onShuffle: () {
                _audio.shuffle();
              },
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
              isFavorite: _authService.isUserLoggedIn()
                  ? currentCloudSongInfo.isFavorite
                  : false,
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
              onShuffle: () {
                _audio.shuffle();
              },
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
              isFavorite: _authService.isUserLoggedIn()
                  ? currentCloudSongInfo.isFavorite
                  : false,
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
        onInfoPressed: (enabled) {
          setState(() {
            _showSongInfo = enabled;
          });
        },
        onListPressed: (enabled) {
          setState(() {
            _showQueue = enabled;
          });
        },
        onEqualizerPressed: (enabled) {
          setState(() {
            _showEqualizer = enabled;
          });
        },
      ),
    ];
  }

  void _toggleFavorite(bool isFavorite) async {
    if (!_authService.isUserLoggedIn()) {
      return;
    }
    setState(() {
      currentCloudSongInfo =
          currentCloudSongInfo.copyWith(isFavorite: isFavorite);
    });

    try {
      await _audio.setFavorite(isFavorite);
    } catch (e) {
      // TODO implement proper ui error handling
      // Revert the optimistic update if the backend operation fails
      setState(() {
        currentCloudSongInfo =
            currentCloudSongInfo.copyWith(isFavorite: !isFavorite);
      });
    }
  }

  void _nextSong() async {
    setState(() {
      currentSongInfo = _audio.getNextSongInfo();
    });

    try {
      await _audio.nextSong();

      if (_authService.isUserLoggedIn()) {
        final songCloudInfo = await _audio.getCurrentSongCloudInfo();
        setState(() {
          currentCloudSongInfo = songCloudInfo;
        });
      }
    } catch (e) {
      // TODO implement proper error handling within the ui
      // TODO detect if the exception was caused by the songcloudinfo API call
      // or if it from the nextSong api call

      // if it is from the nextSong method, no need to do anything because
      // the index w/in the _audio class will have alr been updated
      // but if the cloudSong api call fails we need to figure out what to do then
    }
  }

  void _previousSong() async {
    setState(() {
      currentSongInfo = _audio.getPreviousSongInfo();
    });

    try {
      await _audio.previousSong();
      final songCloudInfo = await _audio.getCurrentSongCloudInfo();
      setState(() {
        currentCloudSongInfo = songCloudInfo;
      });
    } catch (e) {
      // TODO implement proper error handling within the ui
      // TODO detect if the exception was caused by the songcloudinfo API call
      // or if it from the previousSong api call

      // if it is from the previousSong method, no need to do anything because
      // the index w/in the _audio class will have alr been updated
      // but if the cloudSong api call fails we need to figure out what to do then
    }
  }
}
