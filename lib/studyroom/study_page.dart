import 'dart:convert';

import 'package:flourish_web/app_state.dart';
import 'package:flourish_web/studyroom/audio/background_sound.dart';
import 'package:flourish_web/studyroom/control_bar.dart';
import 'package:flourish_web/studyroom/credential_bar.dart';
import 'package:flourish_web/studyroom/studytools/scene.dart';
import 'package:flourish_web/studyroom/widgets/screens/timer.dart';
import 'package:flourish_web/studyroom/widgets/screens/timer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class StudyRoom extends StatefulWidget {
  const StudyRoom({super.key});

  @override
  State<StudyRoom> createState() => _StudyRoomState();
}

class _StudyRoomState extends State<StudyRoom> {
  bool _showTimer = false;
  bool _loadingScene = true;
  PomodoroDurations timerDurations =
      PomodoroDurations(Duration.zero, Duration.zero);

  StudyScene scene = const StudyScene(
    id: 0,
    name: 'Loading...',
    playlistId: 0,
    scenePath: 'Loading...',
    backgroundIds: [0],
    fontTheme: 'Loading...',
  );

  List<StudyScene> scenes = [];

  Future initScenes() async {
    String json = await rootBundle.loadString('assets/scenes/index.json');
    List<dynamic> scenes = await jsonDecode(json);
    List<StudyScene> sceneList =
        scenes.map((scene) => StudyScene.fromJson(scene)).toList();

    return sceneList;
  }

  @override
  void initState() {
    super.initState();
    initScenes().then((scenes) {
      setState(() {
        _loadingScene = false;
        this.scenes = scenes;
        scene = scenes[1];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackgroundImage(),
          _showTimer
              ? TimerDialog(
                  focusTimerDuration: timerDurations.studyTime,
                  breakTimerDuration: timerDurations.breakTime,
                  fontFamily: 'Inter',
                  onExit: (value) {
                    setState(() {
                      _showTimer = false;
                      timerDurations = value;
                    });
                  },
                )
              : const SizedBox.shrink(),
          //buildMainControls(),
        ],
      ),
    );
  }

  Widget buildBackgroundImage() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(scene.scenePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        buildBackgroundNoiseControls(),
        _loadingScene
            ? const SizedBox.shrink()
            : Player(
                playlistId: scene.playlistId,
                scenes: scenes,
                onShowTimer: (value) {
                  setState(() {
                    timerDurations = value;
                    _showTimer = true;
                  });
                },
              ),
        Positioned(
          top: 20,
          right: 20,
          child: Consumer<ApplicationState>(
            builder: (context, appState, child) {
              return CredentialBar(
                loggedIn: appState.loggedIn,
              );
            },
          ),
        ),
      ],
    );
  }

  // TODO make the offsets dynamic based on the screen size so they are not clipped out of view
  Widget buildBackgroundNoiseControls() {
    return const Stack(
      children: [
        BackgroundSoundControl(
          id: 1,
          initialPosition: Offset(1000.0, 500.0),
        ),
        BackgroundSoundControl(
          id: 2,
          initialPosition: Offset(1200.0, 300.0),
        ),
        BackgroundSoundControl(
          id: 3,
          initialPosition: Offset(1000.0, 700.0),
        ),
      ],
    );
  }
}
