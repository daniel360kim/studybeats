import 'dart:ui';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/side_widgets/aichat/aichat.dart';
import 'package:studybeats/studyroom/side_widgets/notes/notes.dart';
import 'package:studybeats/studyroom/side_widgets/scene_select.dart';
import 'package:studybeats/studyroom/side_widgets/timer/study_sessions.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum NavigationOption {
  scene,
  aiChat,
  timer,
  todo,
  notes,
}

class SideWidgetBar extends StatefulWidget {
  const SideWidgetBar({
    required this.onShowTimer,
    required this.onSceneChanged,
    required this.timerFxData,
    required this.onTimerSoundEnabled,
    required this.currentScene,
    required this.currentSceneBackgroundUrl,
    required this.onUpgradeSelected,
    super.key,
  });

  final ValueChanged<PomodoroDurations> onShowTimer;
  final ValueChanged<TimerFxData> timerFxData;
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<int> onSceneChanged;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;
  final ValueChanged<NavigationOption> onUpgradeSelected;

  @override
  State<SideWidgetBar> createState() => SideWidgetBarState();
}

class SideWidgetBarState extends State<SideWidgetBar> {
  NavigationOption? _selectedOption;

  void _onItemTapped(NavigationOption option) {
    setState(() {
      _selectedOption = _selectedOption == option ? null : option;
    });
  }

  void closeAll() {
    setState(() {
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildControlBar(),
        _getSelectedWidget(),
      ],
    );
  }

  Widget _buildControlBar() {
    // This GestureDetector is used to prevent the click event within the
    // side widget bar from propagating to the main screen.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              border: const Border(
                bottom: BorderSide(
                  color: Colors.grey,
                  width: 1.0,
                ),
              ),
            ),
            height: MediaQuery.of(context).size.height - 80,
            width: 50,
            child: Column(
              children: [
                NavigationItem(
                  selectedOption: _selectedOption,
                  toolTip: 'Change scene',
                  option: NavigationOption.scene,
                  imagePath: 'assets/icons/scene.png',
                  onItemTapped: (option) {
                    if (!AuthService().isUserLoggedIn()) {
                      setState(() => _selectedOption = null);
                      _redirectToLogin();
                      return;
                    }
                    _onItemTapped(option);
                  },
                ),
                NavigationItem(
                  selectedOption: _selectedOption,
                  toolTip: 'Studybeats Bot',
                  option: NavigationOption.aiChat,
                  imagePath: 'assets/icons/robot.png',
                  onItemTapped: (option) {
                    if (!AuthService().isUserLoggedIn()) {
                      setState(() => _selectedOption = null);
                      _redirectToLogin();
                      return;
                    }
                    _onItemTapped(option);
                  },
                ),
                NavigationItem(
                  selectedOption: _selectedOption,
                  toolTip: 'Pomodoro Timer',
                  option: NavigationOption.timer,
                  imagePath: 'assets/icons/timer.png',
                  onItemTapped: _onItemTapped,
                ),
                NavigationItem(
                  selectedOption: _selectedOption,
                  toolTip: 'Todo List',
                  option: NavigationOption.todo,
                  imagePath: 'assets/icons/todo.png',
                  onItemTapped: (option) {
                    if (!AuthService().isUserLoggedIn()) {
                      setState(() => _selectedOption = null);
                      _redirectToLogin();
                      return;
                    }
                    _onItemTapped(option);
                  },
                ),
                NavigationItem(
                  selectedOption: _selectedOption,
                  toolTip: 'Notes',
                  option: NavigationOption.notes,
                  imagePath: 'assets/icons/notes.png',
                  onItemTapped: (option) {
                    if (!AuthService().isUserLoggedIn()) {
                      setState(() => _selectedOption = null);
                      _redirectToLogin();
                      return;
                    }
                    _onItemTapped(option);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSelectedWidget() {
    // This GestureDetector is used to prevent the click event within the
    // side widget bar from propagating to the main screen.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Column(
        children: [
          if (AuthService().isUserLoggedIn())
            Visibility(
              maintainState: true,
              visible: _selectedOption == NavigationOption.scene,
              child: SceneSelector(
                onSceneSelected: (id) async {
                  widget.onSceneChanged(id);
                  await AuthService().changeselectedSceneId(id);
                },
                onClose: () => setState(() => _selectedOption = null),
                currentScene: widget.currentScene,
                currentSceneBackgroundUrl: widget.currentSceneBackgroundUrl,
                onProSceneSelected: () {
                  widget.onUpgradeSelected(NavigationOption.scene);
                },
              ),
            ),
          if (AuthService().isUserLoggedIn())
            Visibility(
              maintainState: true,
              visible: _selectedOption == NavigationOption.aiChat,
              child: AiChat(
                onClose: () => setState(() => _selectedOption = null),
                onUpgradePressed: () {
                  widget.onUpgradeSelected(NavigationOption.aiChat);
                },
              ),
            ),
          Visibility(
            maintainState: false,
            visible: _selectedOption == NavigationOption.timer,
            child: PomodoroTimer(
              onTimerSoundEnabled: widget.onTimerSoundEnabled,
              onTimerSoundSelected: widget.timerFxData,
              onStartPressed: (value) {
                widget.onShowTimer(value);
                setState(() => _selectedOption = null);
              },
              onClose: () => setState(() => _selectedOption = null),
            ),
          ),
          if (AuthService().isUserLoggedIn())
            Visibility(
              maintainState: true,
              visible: _selectedOption == NavigationOption.todo,
              child: Todo(
                onClose: () => setState(() => _selectedOption = null),
              ),
            ),
          if (AuthService().isUserLoggedIn())
            Visibility(
              maintainState: true,
              visible: _selectedOption == NavigationOption.notes,
              child: Notes(
                onClose: () => setState(() => _selectedOption = null),
                onUpgradePressed: () {
                  widget.onUpgradeSelected(NavigationOption.notes);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _selectedOption = null);
      context.goNamed(AppRoute.loginPage.name);
    });
    return const SizedBox();
  }
}

class NavigationItem extends StatefulWidget {
  const NavigationItem({
    required this.selectedOption,
    required this.toolTip,
    required this.option,
    required this.imagePath,
    required this.onItemTapped,
    super.key,
  });

  final NavigationOption? selectedOption;
  final String toolTip;
  final NavigationOption option;
  final String imagePath;
  final ValueChanged<NavigationOption> onItemTapped;

  @override
  State<NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<NavigationItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.option == widget.selectedOption;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.toolTip,
        child: Column(
          children: [
            SizedBox(
              height: 50,
              width: 50,
              child: GestureDetector(
                onTap: () => widget.onItemTapped(widget.option),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected || _hovering
                        ? Colors.white.withOpacity(0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, 2),
                              blurRadius: 8.0,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3.0),
          ],
        ),
      ),
    );
  }
}
