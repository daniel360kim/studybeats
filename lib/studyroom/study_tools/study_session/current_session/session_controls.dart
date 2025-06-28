import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/studyroom/study_tools/study_session/current_session/session_task_list.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/session_settings.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/todo_adder.dart';
import 'package:studybeats/theme_provider.dart';

class CurrentSessionControls extends StatefulWidget {
  const CurrentSessionControls({super.key});

  @override
  State<CurrentSessionControls> createState() => _CurrentSessionControlsState();
}

class _CurrentSessionControlsState extends State<CurrentSessionControls> {
  late TextEditingController _titleController;
  bool _isEditingTitle = false;
  final _studySessionService = StudySessionService();
  final FocusNode _focusNode = FocusNode();
  final PageController _taskPageController = PageController();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    initSessionService();

    final session =
        Provider.of<StudySessionModel>(context, listen: false).currentSession;
    _titleController = TextEditingController(text: session?.title ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void initSessionService() async {
    try {
      await _studySessionService.init();
    } catch (e) {
      print("Error initializing StudySessionService: $e");
    }
  }

  Future<void> _confirmAndEndSession(BuildContext context,
      StudySessionModel sessionModel, ThemeProvider themeProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.popupBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'End Session?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: themeProvider.mainTextColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end this study session? Your progress will be saved.',
          style: GoogleFonts.inter(
              fontSize: 14, color: themeProvider.secondaryTextColor),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: themeProvider.dividerColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.mainTextColor),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                final sessionService = StudySessionService();
                await sessionService.init();
                await sessionModel.endSession(sessionService);
                if (mounted) setState(() {});
                Navigator.of(context).pop(true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to end session: $e',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(
              'End Session',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionModel = Provider.of<StudySessionModel>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!_isEditingTitle &&
        _titleController.text != (sessionModel.currentSession?.title ?? '')) {
      _titleController.text = sessionModel.currentSession?.title ?? '';
    }
    if (sessionModel.currentSession == null) {
      return SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: themeProvider.primaryAppColor,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          children: [
            ListView(
              children: [
                buildSessionName(sessionModel, themeProvider),
                const SizedBox(height: 10),
                _buildTotalTimeStats(sessionModel, themeProvider),
                const SizedBox(height: 10),
                _buildSessionSettings(sessionModel),
                const SizedBox(height: 10),
                _buildThemeColorPicker(sessionModel, themeProvider),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeProvider.appContentBackgroundColor
                        .withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _confirmAndEndSession(
                          context, sessionModel, themeProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      maximumSize: const Size(100, 40),
                      minimumSize: const Size(100, 40),
                      backgroundColor: themeProvider.appContentBackgroundColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.redAccent,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      'End Session',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            buildTaskManager(sessionModel, themeProvider),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor:
              themeProvider.appContentBackgroundColor.withOpacity(0.8),
          selectedItemColor: themeProvider.primaryAppColor,
          unselectedItemColor: themeProvider.secondaryTextColor,
          currentIndex: _currentPage,
          onTap: (index) {
            setState(() {
              _currentPage = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Overview',
              tooltip: '',
              activeIcon: Icon(Icons.dashboard),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              label: 'Tasks',
              tooltip: '',
              activeIcon: Icon(Icons.checklist),
            ),
          ],
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          type: BottomNavigationBarType.fixed,
          enableFeedback: false,
          elevation: 0,
        ),
      ),
    );
  }

  Widget buildTaskManager(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 350),
      child: PageView(
        controller: _taskPageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildTaskListCard(sessionModel, themeProvider),
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.appContentBackgroundColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.arrow_back, color: themeProvider.iconColor),
                    tooltip: 'Back to tasks',
                    onPressed: () {
                      _taskPageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TodoAdder(
                    initialSelectedTodoItems:
                        sessionModel.currentSession?.todos ?? {},
                    onTodoItemToggled: (selectedItems) async {
                      await sessionModel.updateSession(
                        sessionModel.currentSession!
                            .copyWith(todos: selectedItems.toList()),
                        _studySessionService,
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTaskListCard(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Session Tasks',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.mainTextColor,
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Add more tasks',
                icon: Icon(Icons.add, color: themeProvider.iconColor),
                onPressed: () {
                  _taskPageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            ],
          ),
          const SizedBox(height: 12),
          if (sessionModel.currentSession!.todos.isEmpty)
            Column(
              children: [
                Text(
                  'No tasks added yet.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.secondaryTextColor,
                  ),
                ),
              ],
            )
          else
            SessionTaskList(
              todoIds: sessionModel.currentSession!.todos,
              taskListVisibleLength: 5,
            ),
        ],
      ),
    );
  }

  Widget _buildTotalTimeStats(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
    final inactiveColor = themeProvider.secondaryTextColor;
    final inactiveBgColor = themeProvider.dividerColor;
    final activeColor = sessionModel.currentSession!.themeColor;
    final activeBgColor = activeColor.withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sessionModel.currentPhase == SessionPhase.studyTime
                    ? activeBgColor
                    : inactiveBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total focus time',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: sessionModel.currentPhase == SessionPhase.studyTime
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(
                      sessionModel.accumulatedStudyDuration +
                          (sessionModel.currentPhase == SessionPhase.studyTime
                              ? DateTime.now()
                                  .difference(sessionModel.startTime)
                              : Duration.zero),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: sessionModel.currentPhase == SessionPhase.studyTime
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sessionModel.currentPhase == SessionPhase.breakTime
                    ? activeBgColor
                    : inactiveBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total break time',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: sessionModel.currentPhase == SessionPhase.breakTime
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(
                      sessionModel.accumulatedBreakDuration +
                          (sessionModel.currentPhase == SessionPhase.breakTime
                              ? DateTime.now()
                                  .difference(sessionModel.startTime)
                              : Duration.zero),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: sessionModel.currentPhase == SessionPhase.breakTime
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSettings(StudySessionModel sessionModel) {
    return SessionSettings(
        outlineEnabled: false,
        onTimerSoundEnabled: (enabled) {
          sessionModel.updateSession(
            sessionModel.currentSession!.copyWith(
              soundEnabled: enabled,
            ),
            _studySessionService,
          );
        },
        onTimerSoundSelected: (selected) {
          sessionModel.updateSession(
            sessionModel.currentSession!.copyWith(
              soundFxId: selected.id,
            ),
            _studySessionService,
          );
        });
  }

  Widget _buildThemeColorPicker(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Color',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.mainTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (final color in [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.orange,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: GestureDetector(
                    onTap: () async {
                      final session = sessionModel.currentSession!;
                      await sessionModel.updateSession(
                        session.copyWith(themeColor: color),
                        _studySessionService,
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              sessionModel.currentSession?.themeColor == color
                                  ? themeProvider.mainTextColor
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget buildSessionName(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Tooltip(
        message: !_isEditingTitle ? 'Edit session name' : '',
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: TapRegion(
              onTapOutside: (_) {
                if (!_isEditingTitle) return;
                setState(() {
                  _isEditingTitle = false;
                  _titleController.text =
                      sessionModel.currentSession?.title ?? '';
                });
              },
              onTapInside: (_) {
                if (_isEditingTitle) return;

                setState(() {
                  _isEditingTitle = true;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 10), () {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                      _titleController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _titleController.text.length),
                      );
                    }
                  });
                });
              },
              child: SizedBox(
                height: 40,
                width: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: themeProvider.primaryAppColor,
                            selectionColor:
                                themeProvider.primaryAppColor.withOpacity(0.3),
                          ),
                        ),
                        child: AbsorbPointer(
                          absorbing: !_isEditingTitle,
                          child: TextField(
                            cursorColor: themeProvider.primaryAppColor,
                            controller: _titleController,
                            readOnly: !_isEditingTitle,
                            focusNode: _focusNode,
                            autofocus: false,
                            showCursor: _isEditingTitle,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.mainTextColor,
                            ),
                            decoration: InputDecoration(
                              enabledBorder: _isEditingTitle
                                  ? UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: themeProvider.primaryAppColor),
                                    )
                                  : InputBorder.none,
                              focusedBorder: _isEditingTitle
                                  ? UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: themeProvider.primaryAppColor))
                                  : InputBorder.none,
                            ),
                            onSubmitted: (value) async {
                              await sessionModel.updateSession(
                                sessionModel.currentSession!
                                    .copyWith(title: value),
                                _studySessionService,
                              );
                              setState(() {
                                _isEditingTitle = false;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_isEditingTitle)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _isEditingTitle = false;
                                _titleController.text =
                                    sessionModel.currentSession?.title ?? '';
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await sessionModel.updateSession(
                                sessionModel.currentSession!
                                    .copyWith(title: _titleController.text),
                                _studySessionService,
                              );
                              setState(() {
                                _isEditingTitle = false;
                              });
                            },
                          ),
                        ],
                      )
                  ],
                ),
              ),
            )),
      ),
    );
  }
}
