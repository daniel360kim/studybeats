import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/widgets/controls/background_sound.dart';
import 'package:flourish_web/studyroom/widgets/controls/player.dart';
import 'package:flutter/material.dart';

class StudyRoom extends StatefulWidget {
  const StudyRoom({super.key});

  @override
  State<StudyRoom> createState() => _StudyRoomState();
}

class _StudyRoomState extends State<StudyRoom> {
  List<Song> songQueue = [];
  Song currentSongInfo = const Song(
    id: 0,
    name: 'Loading...',
    artist: 'Loading...',
    duration: 0,
    link: 'Loading...',
    songPath: '',
    thumbnailPath: '',
  );

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

  // TODO make the offsets dynamic based on the screen size so they are not clipped out of view
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
