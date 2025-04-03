import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/session_inputs.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_inputs.dart';

class NewStudySessionData {
  final String sessionName;
  final Duration studyDuration;
  final Duration breakDuration;
  final List<String> todoIds;

  NewStudySessionData({
    required this.sessionName,
    required this.studyDuration,
    required this.breakDuration,
    this.todoIds = const [],
  });
}

class CreateStudySessionPage extends StatefulWidget {
  final ValueChanged<NewStudySessionData> onSessionCreated;
  final VoidCallback onCancel;

  const CreateStudySessionPage({
    super.key,
    required this.onSessionCreated,
    required this.onCancel,
  });

  @override
  _CreateStudySessionPageState createState() => _CreateStudySessionPageState();
}

class _CreateStudySessionPageState extends State<CreateStudySessionPage>
    with SingleTickerProviderStateMixin {
  final SwiperController _swiperController = SwiperController();

  // Fields to store user inputs.
  String _sessionName = "";
  int _studyMinutes = 25;
  int _breakMinutes = 5;
  List<String> _selectedTodoIds = [];

  // Keep track of which step (0 to 4) the user is on.
  int _currentStep = 0;
  final int _totalSteps = 3;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _fade(bool isFading) {
    if (isFading) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Give the background a dark color to mimic Duolingo's style

      body: SafeArea(
        child: Column(
          children: [
            // Top row with Back button and progress bar
            Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    child: Container(
                      height: 50,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: kFlourishBlackish),
                      onPressed: () {
                        if (_currentStep == 0) {
                          // If at the first step, close/cancel
                          widget.onCancel();
                        } else {
                          // Otherwise, go back to the previous step
                          setState(() {
                            _currentStep--;
                            _swiperController.previous();
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: (_currentStep) / _totalSteps,
                          end: (_currentStep + 1) / _totalSteps,
                        ),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  kFlourishAdobe),
                              backgroundColor: Colors.grey.shade200,
                              value: value,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // The main content (the swiper pages)
            Expanded(
              child: Swiper(
                physics: const NeverScrollableScrollPhysics(),
                controller: _swiperController,
                itemCount: _totalSteps,
                loop: false,
                onIndexChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return SessionInputs(
                        showTimerEditor: (value) {
                          _fade(value);
                        },
                        onSessionInputsChanged: (value) {
                          setState(() {
                            _sessionName = value;
                          });
                        },
                        onContinue: () {
                          _handleNextPressed();
                        },
                      );
                    
                    case 1:
                      return _buildTodoSelectionStep();
                    case 2:
                      return _buildReviewStep();
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextPressed() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _swiperController.next();
      });
    } else {
      // Final step: create the session
      final newSession = NewStudySessionData(
        sessionName: _sessionName,
        studyDuration: Duration(minutes: _studyMinutes),
        breakDuration: Duration(minutes: _breakMinutes),
        todoIds: _selectedTodoIds,
      );
      widget.onSessionCreated(newSession);
    }
  }

  Widget _buildTodoSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StudySessionTodoSelector(
        onSelectionChanged: (selectedIds) {
          setState(() {
            _selectedTodoIds = selectedIds;
          });
        },
      ),
    );
  }

  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Step 5: Review",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Session Name: $_sessionName",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "Study Duration: $_studyMinutes minutes",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "Break Duration: $_breakMinutes minutes",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "Selected Todo IDs: ${_selectedTodoIds.join(', ')}",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "Press 'Create Session' to confirm.",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// You can keep your SessionStepPage and StudySessionTodoSelector classes
/// unchanged if you want, or merge them into the new layout above.
/// For brevity, they are omitted here except for StudySessionTodoSelector.
/// Just make sure they match your current definitions.

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
