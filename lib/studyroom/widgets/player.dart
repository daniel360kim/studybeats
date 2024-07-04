import 'dart:ui';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/audio_controller.dart';
import 'package:flourish_web/studyroom/audio/song_handler.dart';
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
        setState(() {
          currentSongInfo = _audioPlayer.getCurrentSongInfo();
          currentSongIndex = _audioPlayer.getCurrentSongIndex();
        });
      }
    });

    // Set the current song info when the song ends
    _audioPlayer.audioPlayer.positionDiscontinuityStream
        .listen((discontinuity) {
      switch (discontinuity.reason) {
        case PositionDiscontinuityReason.autoAdvance:
          setState(() {
            currentSongInfo =
                _songHandler.songsInfo[_audioPlayer.getCurrentSongIndex() + 1];
            currentSongIndex = _audioPlayer.getCurrentSongIndex() + 1;
          });
          break;
        default:
          break;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      _audioPlayer.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 20.0),
        width: MediaQuery.of(context).size.width,
        height: 100,
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
    return StreamBuilder<PlayerState>(
        stream: _audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final playing = playerState?.playing;
          if (playing != null) {
            return Controls(
              onShuffle: () => {},
              onPrevious: () {},
              onPlay: _audioPlayer.play,
              onPause: _audioPlayer.pause,
              onNext: () {},
              onFavorite: () => print('Favorite'),
              isPlaying: playing,
            );
          } else {
            return const SizedBox.shrink();
          }
        });
  }
}
