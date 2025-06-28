import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/study_tools/study_session/current_session/session_controls.dart';
import 'package:studybeats/studyroom/study_tools/study_session/current_session/session_end_summary.dart';
import 'package:studybeats/studyroom/study_tools/study_session/home/home_page.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/session_inputs.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/todo_adder.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_inputs.dart';
import 'package:studybeats/theme_provider.dart';
import 'package:uuid/uuid.dart';

// Data object for session creation.
class NewStudySessionData {
  final String sessionName;
  final Duration studyDuration;
  final Duration breakDuration;
  final Set<SessionTodoReference> todoIds;

  NewStudySessionData({
    required this.sessionName,
    required this.studyDuration,
    required this.breakDuration,
    required this.todoIds,
  });
}

class SessionPageController extends StatefulWidget {
  final ValueChanged<NewStudySessionData> onSessionCreated;
  final VoidCallback onCancel;

  const SessionPageController({
    super.key,
    required this.onSessionCreated,
    required this.onCancel,
  });

  @override
  _CreateStudySessionPageState createState() => _CreateStudySessionPageState();
}

class _CreateStudySessionPageState extends State<SessionPageController>
    with SingleTickerProviderStateMixin {
  UniqueKey _homeKey = UniqueKey();
  String _sessionName = "Untitled Session";
  Duration _studyDuration = const Duration(minutes: 25);
  Duration _breakDuration = const Duration(minutes: 5);
  Set<SessionTodoReference> _selectedTodoIds = {};
  String? _selectedTodoListId;
  bool _timerSoundEnabled = true;
  int? _selectedTimerFxId;
  bool isLoopSession = true;

  StudySession? _completedSession;

  int _currentPage = 0;

  final PageController _pageController = PageController();
  final StudySessionService _studySessionService = StudySessionService();
  bool _wasSessionActive = false;

  @override
  void initState() {
    super.initState();
    final initialSession = context.read<StudySessionModel>().currentSession;
    _wasSessionActive = initialSession != null;
    initService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionModel = context.read<StudySessionModel>();
      if (sessionModel.currentSession != null) {
        setState(() {
          _currentPage = 3;
          _pageController.jumpToPage(3);
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void initService() async {
    await _studySessionService.init();
  }

  void startNewSession() {
    final studySessionModel = context.read<StudySessionModel>();
    StudySession newStudySession = StudySession(
      id: const Uuid().v4(),
      title: _sessionName,
      startTime: DateTime.now(),
      updatedTime: DateTime.now(),
      endTime: null,
      studyDuration: _studyDuration,
      breakDuration: _breakDuration,
      todos: _selectedTodoIds,
      soundEnabled: _timerSoundEnabled,
      soundFxId: _selectedTimerFxId,
      actualStudyDuration: Duration.zero,
      actualBreakDuration: Duration.zero,
    );

    studySessionModel.startSession(newStudySession, _studySessionService);
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        children: [
          if (_currentPage == 1 || _currentPage == 2)
            IconButton(
              icon: Icon(Icons.arrow_back, color: themeProvider.iconColor),
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        _buildHeader(themeProvider),
        SizedBox(
          height: _currentPage == 1 || _currentPage == 2
              ? MediaQuery.of(context).size.height - 170
              : MediaQuery.of(context).size.height - 130,
          child: Consumer<StudySessionModel>(
            builder: (context, sessionModel, _) {
              final isActive = sessionModel.currentSession != null;
              if (_wasSessionActive && !isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pageController.jumpToPage(4);
                });
              }
              _wasSessionActive = isActive;
              return PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                    if (idx == 0) {
                      _homeKey = UniqueKey();
                    }
                  });
                },
                children: [
                  StudySessionHomePage(
                    key: _homeKey,
                    onSessionStart: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  buildSessionNameTimeInputPage(),
                  buildTaskSelectionPage(themeProvider),
                  CurrentSessionControls(),
                  SessionEndSummary(
                    onClose: () {
                      setState(() {
                        _completedSession = null;
                        _pageController.jumpToPage(0);
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildSessionNameTimeInputPage() {
    return Center(
      child: SessionInputs(
        showTimerEditor: (value) {},
        onSessionNameChangeed: (value) {
          setState(() {
            _sessionName = value;
          });
        },
        onContinuePressed: () {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        onTimerSoundEnabled: (value) {
          setState(() {
            _timerSoundEnabled = value;
          });
        },
        onTimerSoundSelected: (value) {
          setState(() {
            _selectedTimerFxId = value.id;
          });
        },
        onLoopSessionChanged: (value) {
          setState(() {
            isLoopSession = value;
          });
        },
        onBreakTimeChanged: (value) {
          setState(() {
            _breakDuration = value;
          });
        },
        onStudyTimeChanged: (value) {
          setState(() {
            _studyDuration = value;
          });
        },
      ),
    );
  }

  Widget buildTaskSelectionPage(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TodoAdder(
            onTodoItemToggled: (value) => setState(() {
              _selectedTodoIds = value;
            }),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor: themeProvider.primaryAppColor,
                foregroundColor: kFlourishAliceBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                startNewSession();
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                'Start',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudySessionTodoSelector extends StatefulWidget {
  final ValueChanged<List<String>> onSelectionChanged;

  const StudySessionTodoSelector({super.key, required this.onSelectionChanged});

  @override
  State<StudySessionTodoSelector> createState() =>
      _StudySessionTodoSelectorState();
}

class _StudySessionTodoSelectorState extends State<StudySessionTodoSelector> {
  final TodoService _todoService = TodoService();
  final TodoListService _todoListService = TodoListService();
  List<TodoItem> _todos = [];
  final Set<String> _selectedTodoIds = {};

  @override
  void initState() {
    super.initState();
    _todoService.init().then((_) => _fetchTodos());
  }

  Future<void> _fetchTodos() async {
    try {
      final listId = await _todoListService.getDefaultTodoListId();
      final todos = await _todoService.fetchTodoItems(listId);
      if (mounted) {
        setState(() {
          _todos = todos;
        });
      }
    } catch (e) {
      debugPrint("Error fetching todos: $e");
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTodoIds.contains(id)) {
        _selectedTodoIds.remove(id);
      } else {
        _selectedTodoIds.add(id);
      }
    });
    widget.onSelectionChanged(_selectedTodoIds.toList());
  }

  Future<void> _addNewTodo() async {
    final result = await showDialog<TodoItem>(
      context: context,
      builder: (context) => CreateNewTaskInputs(
        onCreateTask: (todo) => Navigator.of(context).pop(todo),
        onClose: () => Navigator.of(context).pop(),
        onError: () {},
      ),
    );
    if (result != null) {
      try {
        final listId = await _todoListService.getDefaultTodoListId();
        await _todoService.addTodoItem(listId: listId, todoItem: result);
        _fetchTodos();
      } catch (e) {
        debugPrint("Error adding new todo: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Tasks for Session",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: themeProvider.mainTextColor,
          ),
        ),
        const SizedBox(height: 10),
        _todos.isEmpty
            ? Text(
                "No tasks found.",
                style: TextStyle(color: themeProvider.secondaryTextColor),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  final todo = _todos[index];
                  final isSelected = _selectedTodoIds.contains(todo.id);
                  return ListTile(
                    title: Text(
                      todo.title,
                      style:
                          GoogleFonts.inter(color: themeProvider.mainTextColor),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleSelection(todo.id),
                      activeColor: Colors.green,
                      checkColor: Colors.white,
                    ),
                    onTap: () => _toggleSelection(todo.id),
                  );
                },
              ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: _addNewTodo,
          child: Text(
            "Add New Task",
            style: GoogleFonts.inter(),
          ),
        ),
      ],
    );
  }
}
