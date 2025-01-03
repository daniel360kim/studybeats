
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/auth/auth_service.dart';
import 'package:flourish_web/api/scenes/objects.dart';
import 'package:flourish_web/api/scenes/scene_service.dart';
import 'package:flourish_web/api/timer_fx/objects.dart';
import 'package:flourish_web/app_state.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/studyroom/audio/background_sound.dart';
import 'package:flourish_web/studyroom/control_bar.dart';
import 'package:flourish_web/studyroom/credential_bar.dart';
import 'package:flourish_web/studyroom/side_widget_bar.dart';
import 'package:flourish_web/studyroom/widgets/screens/timer/timer.dart';
import 'package:flourish_web/studyroom/widgets/screens/timer/timer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // Add the shimmer package

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
  TimerFxData? _timerFxData;

  bool _timerSoundEnabled = false;

  SceneData? _currentScene;
  List<SceneData> _sceneList = [];

  final SceneService _sceneService = SceneService();

  String? _backgroundImageUrl;

  int? _playlistId;

  final _logger = getLogger('StudyRoom Page Widget');

  String formatDuration(Duration duration) {
    // Account for the
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

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
            _loadingScene = true;
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

          if (_currentScene == null) {
            _logger.e('No scenes found');
            _currentScene = null;
            _backgroundImageUrl = null;
            _loadingScene = true;
            _playlistId = null;
            return;
          }

          _backgroundImageUrl = backgroundUrl;
          _playlistId = _currentScene!.playlistId;
          _loadingScene = false;
        });
      });
    } catch (e) {
      _logger.e('Error while initializing scenes $e');
      setState(() {
        _currentScene = null;
        _backgroundImageUrl = null;
        _loadingScene = true;
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
        if (_currentScene == null) {
          _logger.e('No scenes found');
          _currentScene = null;
          _backgroundImageUrl = null;
          _loadingScene = true;
          _playlistId = null;
          return;
        }
        _playlistId = _currentScene!.playlistId;
      });
    } catch (e) {
      _logger.e('Error while changing scene $e');
      _currentScene = null;
      _backgroundImageUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerDuration = timerDurations.studyTime;

    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: _showTimer ? timerDuration.toString() : 'Study Room',
        primaryColor: Theme.of(context).primaryColor.value,
      ),
    );
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
                    // Look at the durations and determine if the timer is on focus or break
                    late final String timeDescription;
                    if (value.studyTime.inSeconds <= 0) {
                      // If the focus time is zero, then the timer is on break
                      timeDescription =
                          formatDuration(value.breakTime);
                    } else {
                      // Otherwise, the timer is on focus
                      timeDescription =
                          formatDuration(value.studyTime);
                    }

                    // Update the application switcher description
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
          // buildMainControls(),
        ],
      ),
    );
  }

  Widget buildBackgroundImage() {
    return Stack(
      children: [
        _loadingScene || _currentScene == null || _backgroundImageUrl == null
            ? Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                ),
              )
            : ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: _backgroundImageUrl!,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.cover,
                ),
              ),
        _loadingScene || _currentScene == null || _backgroundImageUrl == null
            ? Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: MediaQuery.of(context).size.height - 80,
                  width: 50,
                  color: Colors.white,
                ),
              )
            : Positioned(
                top: 0,
                left: 0,
                child: SideWidgetBar(
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
                ),
              ),
        buildBackgroundNoiseControls(),
        _loadingScene || _currentScene == null || _playlistId == null
            ? Align(
                alignment: Alignment.bottomCenter,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[600]!,
                  highlightColor: Colors.grey[300]!,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 80,
                    color: Colors.grey,
                  ),
                ),
              )
            : Player(
                key: ValueKey(_playlistId),
                playlistId: _playlistId!,
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
