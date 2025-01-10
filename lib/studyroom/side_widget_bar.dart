import 'dart:ui';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/timer_fx/objects.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/side_widgets/aichat/aichat.dart';
import 'package:studybeats/studyroom/side_widgets/scene_select.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SideWidgetBar extends StatefulWidget {
  const SideWidgetBar(
      {required this.onShowTimer,
      required this.onSceneChanged,
      required this.timerFxData,
      required this.onTimerSoundEnabled,
      super.key,
      required this.currentScene,
      required this.currentSceneBackgroundUrl});

  final ValueChanged<PomodoroDurations> onShowTimer;
  final ValueChanged<TimerFxData> timerFxData;
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<int> onSceneChanged;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;

  @override
  State<SideWidgetBar> createState() => _SideWidgetBarState();
}

class _SideWidgetBarState extends State<SideWidgetBar> {
  int? _selectedIndex;

  void _onItemTapped(int index) {
    if (!AuthService().isUserLoggedIn()) {
      setState(() {
        _selectedIndex = null;
      });
      _redirectToLogin();
      return;
    }
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
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
    return ClipRRect(
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
                  selectedIndex: _selectedIndex,
                  toolTip: 'Change scene',
                  index: 0,
                  imagePath: 'assets/icons/scene.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  toolTip: 'Studybeats Bot',
                  index: 1,
                  imagePath: 'assets/icons/robot.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  toolTip: 'Pomodoro Timer',
                  index: 2,
                  imagePath: 'assets/icons/timer.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  toolTip: 'Todo List',
                  index: 3,
                  imagePath: 'assets/icons/todo.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
              ],
            )),
      ),
    );
  }

  Widget _getSelectedWidget() {
    return AuthService().isUserLoggedIn()
        ? Column(
            children: [
              Visibility(
                maintainState: true,
                visible: _selectedIndex == 0 && _selectedIndex != null,
                child: SceneSelector(
                  onSceneSelected: ((id) async {
                    widget.onSceneChanged(id);
                    await AuthService().changeselectedSceneId(id);
                  }),
                  onClose: () {
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                  currentScene: widget.currentScene,
                  currentSceneBackgroundUrl: widget.currentSceneBackgroundUrl,
                ),
              ),
              Visibility(
                maintainState: true,
                visible: _selectedIndex == 1 && _selectedIndex != null,
                child: AiChat(onClose: () {
                  setState(() {
                    _selectedIndex = null;
                  });
                }),
              ),
              Visibility(
                maintainState: true,
                visible: _selectedIndex == 2 && _selectedIndex != null,
                child: PomodoroTimer(
                  onTimerSoundEnabled: (value) =>
                      widget.onTimerSoundEnabled(value),
                  onTimerSoundSelected: (value) => widget.timerFxData(value),
                  onStartPressed: (value) {
                    widget.onShowTimer(value);
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                  onClose: () {
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                ),
              ),
              Visibility(
                  maintainState: true,
                  visible: _selectedIndex == 3 && _selectedIndex != null,
                  child: Todo(onClose: () {
                    setState(() {
                      _selectedIndex = null;
                    });
                  })),
            ],
          )
        : const SizedBox();
  }

  Widget _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedIndex = null;
      });
      context.goNamed(AppRoute.loginPage.name);
    });

    return const SizedBox();
  }
}

class NavigationItem extends StatefulWidget {
  const NavigationItem({
    required this.selectedIndex,
    required this.toolTip,
    required this.index,
    required this.imagePath,
    required this.onItemTapped,
    super.key,
  });

  final int? selectedIndex;
  final String toolTip;
  final int index;
  final String imagePath;
  final ValueChanged onItemTapped;

  @override
  State<NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<NavigationItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.index == widget.selectedIndex;
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovering = true;
      }),
      onExit: (_) => setState(() {
        _hovering = false;
      }),
      child: Tooltip(
        message: widget.toolTip,
        child: Column(
          children: [
            SizedBox(
              height: 50,
              width: 50,
              child: GestureDetector(
                onTap: () => widget.onItemTapped(widget.index),
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
            const SizedBox(height: 3.0)
          ],
        ),
      ),
    );
  }
}
