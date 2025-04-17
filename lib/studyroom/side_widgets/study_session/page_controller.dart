import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/current_session/session_controls.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/current_session/session_end_summary.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/home/home_page.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/new_session/session_inputs.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/new_session/todo_adder.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_inputs.dart';
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
  // Fields to store user inputs.
  String _sessionName = "Untitled Session";
  Duration _studyDuration = const Duration(minutes: 25);
  Duration _breakDuration = const Duration(minutes: 5);
  Set<SessionTodoReference> _selectedTodoIds = {};
  String? _selectedTodoListId;
  bool _timerSoundEnabled = true;
  int? _selectedTimerFxId;
  bool isLoopSession = true;

  StudySession?
      _completedSession; // holds the study session that was just finished

  int _currentPage = 0;

  final PageController _pageController = PageController();

  final StudySessionService _studySessionService = StudySessionService();

  @override
  void initState() {
    super.initState();
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
    studySessionModel.addOnSessionEndCallback(() async {
      if (mounted) {
        setState(() {
          _completedSession = studySessionModel.currentSession;
        });
      }

      // Wait until the new frame builds with the new page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients &&
            _pageController.positions.isNotEmpty) {
          // Optional: you could also check the number of children in the PageView
          _pageController.jumpToPage(4);
        }
      });
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        children: [
          if (_currentPage == 1 ||
              _currentPage == 2) // Hide back button on first and last page
            IconButton(
              icon: const Icon(Icons.arrow_back, color: kFlourishBlackish),
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
    return Column(
      children: [
        _buildHeader(),
        SizedBox(
          height: _currentPage == 1 || _currentPage == 2
              ? MediaQuery.of(context).size.height - 170
              : MediaQuery.of(context).size.height - 130,
          child: // Inside SessionPageController build method:
              PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (idx) {
              setState(() {
                _currentPage = idx;
                if (idx == 0) {
                  // Reset the key to force rebuild of home page
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
              buildTaskSelectionPage(),
              // Wrap this with a Scaffold to allow BottomNavigationBar to anchor to bottom
              CurrentSessionControls(),
              if (_completedSession != null)
                // Show session summary only if a session has been completed
                SessionEndSummary(
                  onClose: () {
                    setState(() {
                      _completedSession = null;
                      _pageController.jumpToPage(0);
                    });
                  },
                ),
            ],
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

  Widget buildTaskSelectionPage() {
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
                backgroundColor: kFlourishAdobe,
                foregroundColor: Colors.white,
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

// The StudySessionTodoSelector is included here (it can remain largely unchanged).
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
      setState(() {
        _todos = todos;
      });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Tasks for Session",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _todos.isEmpty
            ? const Text(
                "No tasks found.",
                style: TextStyle(color: Colors.white),
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
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleSelection(todo.id),
                      activeColor: const Color(0xFF58CC02),
                      checkColor: Colors.white,
                    ),
                    onTap: () => _toggleSelection(todo.id),
                  );
                },
              ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF58CC02),
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
