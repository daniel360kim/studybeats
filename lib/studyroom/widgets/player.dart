import 'dart:ui';

import 'package:flourish_web/studyroom/audio/audio_controller.dart';
import 'package:flourish_web/studyroom/audio/songhandler.dart';
import 'package:flutter/material.dart';
import 'controls.dart';

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  final AudioController audioController = AudioController();

  @override
  void initState() {
    super.initState();
    Songhandler songhandler = Songhandler();
    songhandler.init(1).then((_) {
      audioController.initPlayer(songhandler);
      
    });

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
    return Controls(
      onShuffle: () => {},
      onPrevious: () {},
      onPlay: () => audioController.play(),
      onPause: () => audioController.pause(),
      onNext: () {},
      onFavorite: () => print('Favorite'),
    );
  }
}
