import 'dart:ui';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/audio_controller.dart';
import 'package:flourish_web/studyroom/audio/song_handler.dart';
import 'package:flourish_web/studyroom/widgets/controls/icon_controls.dart';
import 'package:flourish_web/studyroom/widgets/controls/songinfo.dart';
import 'package:flourish_web/studyroom/widgets/controls/volume.dart';
import 'package:flourish_web/studyroom/widgets/screens/queue.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'music_controls.dart';

class Player extends StatefulWidget {
  const Player({
    super.key,
  });

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  late final AudioController _audioPlayer;
  late final SongHandler _songHandler;

  Song currentSongInfo = const Song(
    id: 0,
    name: 'Loading...',
    artist: 'Loading...',
    duration: 0,
    link: 'Loading...',
    songPath: '',
    thumbnailPath: '',
  );

  List<Song> songQueue = [];

  int currentSongIndex = 0;

  bool verticalLayout = false;
  bool _showQueue = false;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioController();
    _songHandler = SongHandler(1, _audioPlayer);
    _songHandler.init().then((value) => {
          _audioPlayer.setPlaylist(_songHandler.playlist),
        });

    // Set the current song info when the songs load
    _audioPlayer.audioPlayer.sequenceStateStream.listen((sequenceState) {
      // Check if its loaded by seeing if the song list is empty
      bool? isEmpty = sequenceState?.sequence.isEmpty;
      if (isEmpty != null && !isEmpty) {
        updateSong();
      }
    });

    // Set the current song info when the song ends
    _audioPlayer.audioPlayer.positionDiscontinuityStream
        .listen((discontinuity) {
      switch (discontinuity.reason) {
        case PositionDiscontinuityReason.autoAdvance:
          updateSong();
          break;
        default:
          break;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audioPlayer.pause();
  }

  @override
  void dispose() {
    _audioPlayer.pause();
    _audioPlayer.dispose();
    super.dispose();
  }

  void updateSong() {
    setState(() {
      currentSongInfo = _audioPlayer.getCurrentSongInfo();
      currentSongIndex = _audioPlayer.getCurrentSongIndex();
      songQueue = _audioPlayer.getSongOrder(currentSongIndex + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _showQueue
            ? Align(
                alignment: Alignment.bottomRight,
                child: SongQueue(
                  currentSong: currentSongInfo,
                  queue: songQueue,
                  onSongSelected: (index) {
                    _audioPlayer.play();
                    _audioPlayer.seekToIndex(index).then((value) {
                      updateSong();
                    });
                  },
                ),
              )
            : const SizedBox.shrink(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 20.0),
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
      borderRadius: _showQueue
          ? const BorderRadius.only(
              topLeft: Radius.circular(20.0),
              bottomLeft: Radius.circular(20.0),
              bottomRight: Radius.circular(20.0),
            )
          : const BorderRadius.all(Radius.circular(20.0)),
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
      if (constraints.maxWidth > 1000) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: buildControlWidgets(),
        );
      } else {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: buildControlWidgets(),
        );
      }
    });
  }

  List<Widget> buildControlWidgets() {
    return [
      StreamBuilder<PlayerState>(
        stream: _audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final playing = playerState?.playing;
          if (playing != null) {
            return Controls(
              onShuffle: () => {},
              onPrevious: () {
                _audioPlayer.previousSong();
                updateSong();
              },
              onPlay: _audioPlayer.play,
              onPause: _audioPlayer.pause,
              onNext: () {
                _audioPlayer.nextSong();
                updateSong();
              },
              onFavorite: () => print('Favorite'),
              isPlaying: playing,
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
      SongInfo(
        song: currentSongInfo,
        positionData: _audioPlayer.positionDataStream,
        onSeekRequested: (newPosition) => _audioPlayer.seek(newPosition),
      ),
      VolumeSlider(
        volumeChanged: (volume) => _audioPlayer.setVolume(volume),
      ),
      IconControls(
        onInfoPressed: (enabled) {},
        onListPressed: (enabled) {
          setState(() {
            _showQueue = enabled;
          });
        },
        onSharePressed: (enabled) {},
      ),
    ];
  }
}
