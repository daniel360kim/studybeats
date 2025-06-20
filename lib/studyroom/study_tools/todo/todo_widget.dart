import 'package:provider/provider.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/study_tools/study_session/current_session/session_task_list.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/todo_adder.dart';

import 'package:studybeats/studyroom/study_tools/todo/todo_inputs.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_list.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class Todo extends StatefulWidget {
  const Todo({
    required this.onClose,
    super.key,
  });

  final VoidCallback onClose;

  @override
  _TodoState createState() => _TodoState();
}

class _TodoState extends State<Todo> {
  final _todoService = TodoService();
  final _todoListService = TodoListService();

  List<TodoList>? _todoLists;
  List<TodoItem>? _uncompletedTodoItems;
  bool _creatingNewTask = false;
  SortBy _selectedSortOption = SortBy.dueDate;
  TodoFilter _selectedFilterOption = TodoFilter.none;

  String? _selectedListId;

  bool _isAnonymous = false;
  bool _dismissedAnonWarning = false;

  @override
  void initState() {
    super.initState();
    _fetchTodoItems();
    initStudyService();
    _initAuth();
  }

  void _initAuth() async {
    final authService = AuthService();
    final isAnonymous = await authService.isUserAnonymous();
    if (mounted) {
      setState(() {
        _isAnonymous = isAnonymous;
      });
    }
  }

  void _fetchTodoItems() async {
    try {
      await _todoService.init();
      await _todoListService.init();

      final todoLists = await _todoListService.fetchTodoLists();

      final uncompletedTodoItems = todoLists.first.categories.uncompleted;
      setState(() {
        _todoLists = todoLists;
        _selectedListId = todoLists.first.id;
        _uncompletedTodoItems = uncompletedTodoItems;
      });
    } catch (e) {
      // Handle error state more gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch todo items: $e')),
      );
    }
  }

  final PageController _taskPageController = PageController(
    initialPage: 0,
  );

  final StudySessionService _studySessionService = StudySessionService();

  void initStudyService() async {
    try {
      await _studySessionService.init();
    } catch (e) {
      // Handle error state more gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Something went wrong. Please try again later.')),
      );
    }
  }

  @override
  void dispose() {
    _taskPageController.dispose();
    super.dispose();
  }

  Widget buildTaskManager(StudySessionModel sessionModel) {
    return SizedBox(
      width: 400,
      height: MediaQuery.of(context).size.height - kControlBarHeight,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height - kControlBarHeight - 70,
            child: PageView(
              controller: _taskPageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTaskListCard(sessionModel),
                SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
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
                          // Pass in the already added todos from the current session as initial selection
                          initialSelectedTodoItems:
                              sessionModel.currentSession?.todos ?? {},
                          // Update the session by replacing the entire todos set
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
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListCard(StudySessionModel sessionModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
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
                  color: kFlourishBlackish,
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Add more tasks',
                icon: const Icon(Icons.add),
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
                    color: Colors.grey.shade700,
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

  Widget buildDefaultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todo',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        if (_isAnonymous && !_dismissedAnonWarning)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 20, color: Color(0xFFF57C00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tasks won't be saved unless you're logged in.",
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6D4C41),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: Color(0xFF6D4C41)),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _dismissedAnonWarning = true;
                    });
                  },
                ),
              ],
            ),
          ),
        if (_creatingNewTask)
          CreateNewTaskInputs(
            onCreateTask: (newTask) async {
              setState(() {
                if (_uncompletedTodoItems == null) {
                  _uncompletedTodoItems = [newTask];
                } else {
                  _uncompletedTodoItems = [
                    newTask,
                    ..._uncompletedTodoItems!,
                  ];

                  _creatingNewTask = false;
                }
              });
              try {
                final listId = await _todoListService.getDefaultTodoListId();
                await _todoService.addTodoItem(
                  listId: listId,
                  todoItem: newTask,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to create task'),
                  ),
                );
                setState(() {
                  _creatingNewTask = false;
                });
              }
            },
            onClose: () => setState(() {
              _creatingNewTask = false;
            }),
            onError: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to create task'),
                ),
              );
              setState(() {
                _creatingNewTask = false;
              });
            },
          )
        else
          Row(
            children: [
              AddTaskButton(onPressed: () {
                setState(() {
                  _creatingNewTask = true;
                });
              }),
              buildPopupMenuButton(),
            ],
          ),
        const SizedBox(height: 16),
        if (_uncompletedTodoItems != null ||
            _uncompletedTodoItems!.isNotEmpty ||
            _selectedListId != null)
          Expanded(
            child: TodoListWidget(
              uncompletedStream:
                  _todoService.streamUncompletedTodoItems(_todoLists!.first.id),
              sortBy: _selectedSortOption,
              filter: _selectedFilterOption,
              listId: _selectedListId!,
              todoService: _todoService,
              onItemMarkedAsDone: (id) async {
                try {
                  setState(() {
                    _uncompletedTodoItems = _uncompletedTodoItems!
                        .where((item) => item.id != id)
                        .toList();
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to mark task as done'),
                    ),
                  );
                }
              },
              onItemDetailsChanged: (newItem) {
                try {
                  final listId = _todoLists!.first.id;
                  _todoService.updateIncompleteTodoItem(
                      listId: listId, updatedItem: newItem);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update task'),
                    ),
                  );
                }
              },
              onItemDelete: (id) {
                try {
                  final listId = _todoLists!.first.id;
                  _todoService.deleteUncompletedItem(listId, id);
                  setState(() {
                    _uncompletedTodoItems = _uncompletedTodoItems!
                        .where((i) => i.id != id)
                        .toList();
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete task'),
                    ),
                  );
                }
              },
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final studySession = Provider.of<StudySessionModel>(context);
    return _todoLists == null
        ? Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: MediaQuery.of(context).size.height - kControlBarHeight,
              width: 400,
              color: Colors.white,
            ),
          )
        : SizedBox(
            width: 400,
            height: MediaQuery.of(context).size.height - kControlBarHeight,
            child: Column(
              children: [
                buildTopBar(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFFE0E7FF),
                          Color(0xFFF7F8FC),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(15.0),
                    child: studySession.isActive
                        ? buildTaskManager(studySession)
                        : buildDefaultList(),
                  ),
                ),
              ],
            ),
          );
  }

  PopupMenuButton<dynamic> buildPopupMenuButton() {
    return PopupMenuButton<dynamic>(
      onSelected: (value) {
        if (value is SortBy) {
          setState(() {
            _selectedSortOption = value;
          });
        } else if (value is TodoFilter) {
          setState(() {
            _selectedFilterOption = value;
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text('Sort By',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem<SortBy>(
          value: SortBy.dueDate,
          child: Row(
            children: [
              if (_selectedSortOption == SortBy.dueDate)
                const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              const Text('Due Date'),
            ],
          ),
        ),
        PopupMenuItem<SortBy>(
          value: SortBy.createdAt,
          child: Row(
            children: [
              if (_selectedSortOption == SortBy.createdAt)
                const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              const Text('Created At'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Text('Filter By',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.none,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.none)
                const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              const Text('None'),
            ],
          ),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.hasDueDate,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.hasDueDate)
                const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              const Text('Has Due Date'),
            ],
          ),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.priority,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.priority)
                const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              const Text('Priority'),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_horiz),
      iconSize: 25,
    );
  }

  Widget buildTopBar() {
    return Container(
      height: 40,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
