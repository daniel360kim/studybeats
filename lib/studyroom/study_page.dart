import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/scenes/scene_service.dart';
import 'package:studybeats/api/timer_fx/objects.dart';
import 'package:studybeats/app_state.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/credential_bar.dart';
import 'package:studybeats/studyroom/side_widget_bar.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// Add the shimmer package

class StudyRoom extends StatefulWidget {
  const StudyRoom({super.key});

  @override
  State<StudyRoom> createState() => _StudyRoomState();
}

class _StudyRoomState extends State<StudyRoom> {
  bool _showTimer = false;
  bool _loadingScene = true;
  bool _loadingControlBar = true;
  bool _splashFinished = false;
  PomodoroDurations timerDurations =
      PomodoroDurations(Duration.zero, Duration.zero);
  TimerFxData? _timerFxData;

  bool _timerSoundEnabled = false;

  SceneData? _currentScene;
  List<SceneData> _sceneList = [];

  final SceneService _sceneService = SceneService();

  String? _backgroundImageUrl;

  int? _playlistId;

  final _logger = getLogger('StudyRoom Page Widget');

  @override
  void initState() {
    super.initState();
    initScenes();
  }

  void initScenes() {
    try {
      _sceneService.getSceneData().then((value) async {
        _logger.i('Scenes initialized');
        if (value.isEmpty) {
          _logger.e('No scenes found');
          setState(() {
            _currentScene = null;
            _backgroundImageUrl = null;
            _loadingScene =
                false; // Ensure loading state is false even if empty
            _playlistId = null;
          });
          return;
        }
        final initialSceneIndex = await AuthService().getselectedSceneId();
        _logger.i('Initial scene index $initialSceneIndex');
        final backgroundUrl = await _sceneService.getBackgroundImageUrl(
            value.where((element) => element.id == initialSceneIndex).first);

        setState(() {
          _sceneList = value;
          _currentScene = _sceneList.firstWhere(
              (scene) => scene.id == initialSceneIndex,
              orElse: () => _sceneList.first);

          _backgroundImageUrl = backgroundUrl;
          _playlistId = _currentScene?.playlistId;
          _loadingScene = false;
        });
      });
    } catch (e) {
      _logger.e('Error while initializing scenes $e');
      setState(() {
        _currentScene = null;
        _backgroundImageUrl = null;
        _loadingScene = false;
        _playlistId = null;
      });
    }
  }

  void changeScene(int id) async {
    try {
      setState(() {
        _currentScene = _sceneList.firstWhere((scene) => scene.id == id);
      });

      if (_currentScene == null) {
        _logger.e('Scene with id $id not found');
        return;
      }

      final url = await _sceneService.getBackgroundImageUrl(_currentScene!);
      setState(() {
        _backgroundImageUrl = url;
        _playlistId = _currentScene?.playlistId;
      });
    } catch (e) {
      _logger.e('Error while changing scene $e');
      setState(() {
        _currentScene = null;
        _backgroundImageUrl = null;
        _playlistId = null;
      });
    }
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
                  timerSoundEnabled: _timerSoundEnabled,
                  timerFxData: _timerFxData!,
                  onTimerDurationChanged: (value) {
                    final timeDescription = formatDuration(value);

                    SystemChrome.setApplicationSwitcherDescription(
                      ApplicationSwitcherDescription(
                        label: timeDescription,
                        primaryColor: Theme.of(context).primaryColor.value,
                      ),
                    );
                  },
                  onExit: (value) {
                    setState(() {
                      _showTimer = false;
                      timerDurations = value;
                    });

                    SystemChrome.setApplicationSwitcherDescription(
                      ApplicationSwitcherDescription(
                        label: 'Study Room',
                        primaryColor: Theme.of(context).primaryColor.value,
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget buildBackgroundImage() {
    return Stack(
      children: [
        if (_backgroundImageUrl != null)
          ClipRRect(
            child: CachedNetworkImage(
              imageUrl: _backgroundImageUrl!,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              fit: BoxFit.cover,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          child: _currentScene != null
              ? SideWidgetBar(
                  onTimerSoundEnabled: (value) => setState(() {
                    _timerSoundEnabled = value;
                  }),
                  timerFxData: (value) => setState(() {
                    _timerFxData = value;
                  }),
                  onShowTimer: (value) {
                    setState(() {
                      timerDurations = value;
                      _showTimer = true;
                    });
                  },
                  onSceneChanged: (id) {
                    changeScene(id);
                  },
                  currentScene: _currentScene!,
                  currentSceneBackgroundUrl: _backgroundImageUrl!,
                )
              : const SizedBox.shrink(),
        ),
        if (_playlistId != null)
          Player(
            key: ValueKey(_playlistId),
            playlistId: _playlistId!,
            onLoaded: () {
              setState(() {
                _loadingControlBar = false;
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
                onLogout: () {
                  setState(() {});
                },
              );
            },
          ),
        ),
       
      ],
    );
  }

  String formatDuration(TabDescriptionReporter report) {
    // Determine the type description
    late String typeDescription = 'Break:';
    if (report.isFocus) {
      typeDescription = 'Focus:';
    }

    // Helper to format two-digit numbers
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    // Extract hours, minutes, and seconds
    final hours = twoDigits(report.duration.inHours);
    final minutes = twoDigits(report.duration.inMinutes.remainder(60));
    final seconds = twoDigits(report.duration.inSeconds.remainder(60));

    // Format the output string
    if (report.duration.inHours > 0) {
      // Include hours if they are greater than 0
      return '$typeDescription $hours:$minutes:$seconds';
    } else {
      // Omit hours if they are 0
      return '$typeDescription $minutes:$seconds';
    }
  }
}
