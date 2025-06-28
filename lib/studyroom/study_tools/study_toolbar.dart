import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/theme_provider.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/study_tools/aichat/aichat.dart';
import 'package:studybeats/studyroom/study_tools/notes/notes.dart';
import 'package:studybeats/studyroom/study_tools/scene_select.dart';
import 'package:studybeats/studyroom/study_tools/study_session/study_sessions.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_widget.dart';

enum NavigationOption {
  scene,
  aiChat,
  timer,
  todo,
  notes,
}

class StudyToolbar extends StatefulWidget {
  const StudyToolbar({
    required this.onSceneChanged,
    required this.currentScene,
    required this.currentSceneBackgroundUrl,
    required this.onUpgradeSelected,
    required this.onOpenLoginDialog,
    super.key,
  });

  final ValueChanged<int> onSceneChanged;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;
  final ValueChanged<NavigationOption> onUpgradeSelected;
  final ValueChanged<int> onOpenLoginDialog;

  @override
  State<StudyToolbar> createState() => StudyToolbarState();
}

class StudyToolbarState extends State<StudyToolbar> {
  // NavigationOption? _selectedOption; // <-- DELETED. State is now in the provider.

  // These keys are for UI positioning (showMenu) and are fine to keep here.
  final GlobalKey _aiChatKey = GlobalKey();
  final GlobalKey _timerKey = GlobalKey();
  final GlobalKey _todoKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();

  // This is local component state, unrelated to navigation, so it stays.
  bool _isUserAnonymous = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() async {
    final isUserAnonymous = await AuthService().isUserAnonymous();
    if (mounted) {
      setState(() {
        _isUserAnonymous = isUserAnonymous;
      });
    }
  }

  void _showLoginMenu(GlobalKey key) {
    final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.of(context).size;
    final double leftMargin = offset.dx + box.size.width;
    final double topMargin = offset.dy;
    final double rightMargin = screenSize.width - offset.dx;
    final double bottomMargin = screenSize.height - offset.dy - box.size.height;

    showMenu(
      color: Colors.transparent,
      context: context,
      position: RelativeRect.fromLTRB(
        leftMargin,
        topMargin,
        rightMargin,
        bottomMargin,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.all(0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/flat/abstract.png',
                      height: 160,
                      width: 280,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Use advanced features for free',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: kFlourishBlackish),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save tasks, start study sessions, and jot notes by logging in',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () =>
                                  context.goNamed(AppRoute.loginPage.name),
                              child: Text(
                                'Log in',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () =>
                                  context.goNamed(AppRoute.signUpPage.name),
                              child: Text(
                                'Sign up',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // void _onItemTapped(NavigationOption option) { ... } // <-- DELETED
  // void closeAll() { ... } // <-- DELETED

  @override
  Widget build(BuildContext context) {
    // Get the StudyToolbarController from the provider.
    // Using .watch() ensures this widget rebuilds when the state changes.
    final controller = context.watch<StudyToolbarController>();

    final theme = Provider.of<ThemeProvider>(context);

    return Row(
      children: [
        _buildControlBar(controller, theme),
        _getSelectedWidget(controller),
      ],
    );
  }

  Widget _buildControlBar(
      StudyToolbarController controller, ThemeProvider theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.emphasisColor.withOpacity(0.8),
              border: Border(
                bottom: BorderSide(
                    color: theme.lightEmphasisColor.withOpacity(0.3),
                    width: 1.0),
              ),
            ),
            height: MediaQuery.of(context).size.height - kControlBarHeight,
            width: 50,
            child: Column(
              children: [
                NavigationItem(
                  selectedOption: controller.selectedOption,
                  toolTip: 'Change scene',
                  option: NavigationOption.scene,
                  imagePath: 'assets/icons/scene.png',
                  onItemTapped: (option) {
                    context.read<StudyToolbarController>().toggleOption(option);
                  },
                ),
                NavigationItem(
                  key: _aiChatKey,
                  selectedOption: controller.selectedOption,
                  toolTip: 'Studybeats Bot',
                  option: NavigationOption.aiChat,
                  imagePath: 'assets/icons/robot.png',
                  onItemTapped: (option) {
                    context.read<StudyToolbarController>().toggleOption(option);
                  },
                ),
                NavigationItem(
                  key: _timerKey,
                  selectedOption: controller.selectedOption,
                  toolTip: 'Focus Session',
                  option: NavigationOption.timer,
                  imagePath: 'assets/icons/timer.png',
                  onItemTapped: (option) {
                    context.read<StudyToolbarController>().toggleOption(option);
                  },
                ),
                NavigationItem(
                  key: _todoKey,
                  selectedOption: controller.selectedOption,
                  toolTip: 'Todo List',
                  option: NavigationOption.todo,
                  imagePath: 'assets/icons/todo.png',
                  onItemTapped: (option) {
                    context.read<StudyToolbarController>().toggleOption(option);
                  },
                ),
                NavigationItem(
                  key: _notesKey,
                  selectedOption: controller.selectedOption,
                  toolTip: 'Notes',
                  option: NavigationOption.notes,
                  imagePath: 'assets/icons/notes.png',
                  onItemTapped: (option) {
                    context.read<StudyToolbarController>().toggleOption(option);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSelectedWidget(StudyToolbarController controller) {
    // Use .read here for the onClose callbacks since they don't need to listen for changes.
    final navRead = context.read<StudyToolbarController>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Column(
        children: [
          Visibility(
            maintainState: true,
            visible: controller.selectedOption == NavigationOption.scene,
            child: SceneSelector(
              onSceneSelected: (id) async {
                widget.onSceneChanged(id);
                if (!_isUserAnonymous) {
                  await AuthService().changeselectedSceneId(id);
                }
              },
              onClose: () => navRead.closePanel(),
              currentScene: widget.currentScene,
              currentSceneBackgroundUrl: widget.currentSceneBackgroundUrl,
              onProSceneSelected: () {
                if (_isUserAnonymous) {
                  navRead.closePanel();
                  _redirectToLogin();
                  return;
                }
                widget.onUpgradeSelected(NavigationOption.scene);
              },
            ),
          ),
          Visibility(
            maintainState: false,
            visible: controller.selectedOption == NavigationOption.aiChat,
            child: AiChat(
              onClose: () => navRead.closePanel(),
              onUpgradePressed: () {
                widget.onUpgradeSelected(NavigationOption.aiChat);
              },
            ),
          ),
          Visibility(
            maintainState: false,
            visible: controller.selectedOption == NavigationOption.timer,
            child: StudySessionSideWidget(
              onClose: () => navRead.closePanel(),
            ),
          ),
          Visibility(
            maintainState: false,
            visible: controller.selectedOption == NavigationOption.todo,
            child: Todo(
              onClose: () => navRead.closePanel(),
            ),
          ),
          Visibility(
            maintainState: false,
            visible: controller.selectedOption == NavigationOption.notes,
            child: Notes(
              onClose: () => navRead.closePanel(),
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
      context.read<StudyToolbarController>().closePanel();
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
    final theme = Provider.of<ThemeProvider>(context);
    final bool isSelected = widget.option == widget.selectedOption;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.toolTip,
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  height: 50,
                  width: 50,
                  child: GestureDetector(
                    onTap: () {
                      widget.onItemTapped(widget.option);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected || _hovering
                            ? theme.emphasisColor.withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      theme.lightEmphasisColor.withOpacity(0.5),
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
              ],
            ),
            const SizedBox(height: 3.0),
          ],
        ),
      ),
    );
  }
}
