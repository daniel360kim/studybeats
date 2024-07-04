import 'package:flourish_web/studyroom/audio/background_sound.dart';
import 'package:flourish_web/studyroom/widgets/player.dart';
import 'package:flutter/material.dart';

class StudyRoom extends StatelessWidget {
  const StudyRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackgroundImage(),
          //buildMainControls(),
        ],
      ),
    );
  }

  Widget buildBackgroundImage() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/jazzcafe.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        buildBackgroundNoiseControls(),
        const Player(),
      ],
    );
  }

  Widget buildBackgroundNoiseControls() {
    return const Stack(
      children: [
        BackgroundSound(
          icon: Icon(Icons.cloud),
          backgroundSoundId: 1,
          initialPosition: Offset(1000.0, 500.0),
        ),
        BackgroundSound(
          icon: Icon(Icons.traffic),
          backgroundSoundId: 2,
          initialPosition: Offset(2000.0, 300.0),
        ),
        BackgroundSound(
          icon: Icon(Icons.thunderstorm),
          backgroundSoundId: 3,
          initialPosition: Offset(250.0, 700.0),
        ),
      ],
    );
  }
}
