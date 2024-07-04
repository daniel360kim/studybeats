import 'dart:ui';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/audio_controller.dart';
import 'package:flourish_web/studyroom/audio/song_handler.dart';
import 'package:flourish_web/studyroom/widgets/songinfo.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'controls.dart';

class Player extends StatefulWidget {
  const Player({super.key});

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
  );

  int currentSongIndex = 0;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioController();
    _songHandler = SongHandler(3, _audioPlayer);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 20.0),
        width: MediaQuery.of(context).size.width,
        height: 80,
        child: Stack(
          children: [
            buildBackdrop(),
            buildControls(),
          ],
        ),
      ),
    );
  }

  Widget buildBackdrop() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget buildControls() {
    return Row(
      children: [
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
      ],
    );
  }
}
