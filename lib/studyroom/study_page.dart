import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/scenes/scene_service.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/app_state.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/credential_bar.dart';
import 'package:studybeats/studyroom/playlist_notifier.dart';
import 'package:studybeats/studyroom/side_widget_bar.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/current_session/study_session_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/upgrade_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studybeats/studyroom/welcome_widget.dart';

class StudyRoom extends StatefulWidget {
  const StudyRoom({this.openPricing = false, super.key});

  final bool openPricing;

  @override
  State<StudyRoom> createState() => _StudyRoomState();
}

class _StudyRoomState extends State<StudyRoom> {
  bool _loadingScene = true;
  bool _loadingControlBar = true;
  final bool _splashFinished = false;
  SceneData? _currentScene;
  List<SceneData> _sceneList = [];
  final SceneService _sceneService = SceneService();
  String? _backgroundImageUrl;
  int? _playlistId;
  final _logger = getLogger('StudyRoom Page Widget');

  final GlobalKey<SideWidgetBarState> _sideWidgetKey =
      GlobalKey<SideWidgetBarState>();
  GlobalKey<PlayerWidgetState> _playerWidgetKey =
      GlobalKey<PlayerWidgetState>();

  final StudySessionService _studySessionService =
      StudySessionService(); // Assuming this is the correct service

  bool showLoginDialog = true;
  int loginDialogOffset = 0;

  bool _showWelcomePopup = false;

  @override
  void initState() {
    super.initState();
    initScenes();
    initAuth();

    checkFirstVisit();
    if (widget.openPricing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showInitialUpgradeDialog();
      });
    }
  }

  void checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVisited = prefs.getBool('hasVisited') ?? false;

    if (!hasVisited) {
      setState(() {
        _showWelcomePopup = true;
      });
      await prefs.setBool('hasVisited', true);
    }
  }

  void initAuth() async {
    try {
      final authService = AuthService();
      if (!authService.isUserLoggedIn()) {
        await authService.logInAnonymously();
        await authService.logUserUsage();
      }
    } catch (e) {
      _logger.e('Error while initializing auth $e');
    }
  }

  void initStudySession() async {
    try {
      await SystemChrome.setApplicationSwitcherDescription(
        const ApplicationSwitcherDescription(
          label: 'Studybeats',
        ),
      );
      await _studySessionService.init();
    } catch (e) {
      // TODO implement proper error handling
      _logger.e('Error while initializing study session $e');
    }
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
            _loadingScene = false;
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

        // Update the notifier with the new playlistId
        Provider.of<PlaylistNotifier>(context, listen: false)
            .updatePlaylistId(_playlistId);
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
      });

      // Update the notifier with the new playlistId
      final newPlaylistId = _currentScene?.playlistId;
      setState(() {
        _playerWidgetKey = GlobalKey<PlayerWidgetState>();
      });
      Provider.of<PlaylistNotifier>(context, listen: false)
          .updatePlaylistId(newPlaylistId);
    } catch (e) {
      _logger.e('Error while changing scene $e');
      setState(() {
        _currentScene = null;
        _backgroundImageUrl = null;
      });
      Provider.of<PlaylistNotifier>(context, listen: false)
          .updatePlaylistId(null);
    }
  }

  // Used when a redirect to the study room wants the pricing dialog to be shown.
  // For example, if on landing page, the user clicks on the "Get Started" button.
  // This will show the pricing dialog initially
  void showInitialUpgradeDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const PremiumUpgradeDialog(
        title: 'Upgrade to Pro',
        description:
            'Unlock premium features and boost your productivity by upgrading to Pro!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionModel = context.watch<StudySessionModel>();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // When tapping anywhere outside, close any open side widget.
        _sideWidgetKey.currentState?.closeAll();

        _playerWidgetKey.currentState?.closeAllWidgets();
      },
      child: Scaffold(
        body: Stack(
          children: [
            buildBackgroundImage(),
            if (sessionModel.isActive) StudySessionDialog(),
            if (_showWelcomePopup)
              WelcomePopup(
                  onClose: () => setState(() => _showWelcomePopup = false)),
          ],
        ),
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
              ? Row(
                  children: [
                    SideWidgetBar(
                      onOpenLoginDialog: (index) {},
                      key: _sideWidgetKey,
                      onSceneChanged: (id) {
                        changeScene(id);
                      },
                      currentScene: _currentScene!,
                      currentSceneBackgroundUrl: _backgroundImageUrl!,
                      onUpgradeSelected: (option) async {
                        // Show the upgrade dialog
                        switch (option) {
                          case NavigationOption.scene:
                            await showDialog(
                              context: context,
                              builder: (_) => const PremiumUpgradeDialog(
                                title: 'Unlock more scenes',
                                description:
                                    'Get access to more scenes, new genres, and more!',
                              ),
                            );
                            break;
                          case NavigationOption.notes:
                            await showDialog(
                              context: context,
                              builder: (_) => const PremiumUpgradeDialog(
                                title: 'Unlock more notes',
                                description:
                                    'With Pro, you can create unlimited notes and get access to more features!',
                              ),
                            );

                            break;
                          case NavigationOption.aiChat:
                            await showDialog(
                              context: context,
                              builder: (_) => const PremiumUpgradeDialog(
                                title: 'Unlimited chats with AI',
                                description:
                                    'Get unlimited access and uploads to the Studybeats AI chat!',
                              ),
                            );
                            break;
                          default:
                            break;
                        }
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        if (_playlistId != null)
          if (_playlistId != null)
            Positioned(
              // Adjust position as needed...
              child: Consumer<PlaylistNotifier>(
                builder: (context, playlistNotifier, child) {
                  return playlistNotifier.playlistId != null
                      ? Container(
                          // Use a ValueKey on the container to force rebuild when playlistId changes.
                          key: ValueKey(playlistNotifier.playlistId),
                          child: PlayerWidget(
                            key:
                                _playerWidgetKey, // Your persistent GlobalKey stays here.
                            playlistId: playlistNotifier.playlistId!,
                            onLoaded: () {
                              setState(() {
                                _loadingControlBar = false;
                              });
                            },
                          ),
                        )
                      : SizedBox.shrink();
                },
              ),
            ),
        Positioned(
          top: 20,
          right: 20,
          child:  CredentialBar(
                onUpgradePressed: showInitialUpgradeDialog,
                onLogout: () async {
                  changeScene(1);

                  if (mounted) {
                    setState(() {});
                  }
                },
              )
            
          
        ),
      ],
    );
  }
}

/// A dialog that shows upgrade details and provides buttons for different upgrade options.
/// Each button returns a different [NavigationOption] value.
class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upgrade to Premium'),
      content: const Text(
          'Unlock premium features such as custom scenes, advanced timers, and AI chat enhancements by upgrading now!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(NavigationOption.scene),
          child: const Text('Upgrade Scene'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(NavigationOption.timer),
          child: const Text('Upgrade Timer'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(NavigationOption.aiChat),
          child: const Text('Upgrade AI Chat'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Cancel returns null.
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
