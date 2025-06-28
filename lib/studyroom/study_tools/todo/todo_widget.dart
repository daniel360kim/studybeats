import 'package:provider/provider.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/study_tools/study_session/current_session/session_task_list.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/todo_adder.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_inputs.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_list.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/theme_provider.dart';

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
      if (mounted && todoLists.isNotEmpty) {
        final uncompletedTodoItems = todoLists.first.categories.uncompleted;
        setState(() {
          _todoLists = todoLists;
          _selectedListId = todoLists.first.id;
          _uncompletedTodoItems = uncompletedTodoItems;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch todo items: $e')),
        );
      }
    }
  }

  final PageController _taskPageController = PageController(initialPage: 0);
  final StudySessionService _studySessionService = StudySessionService();

  void initStudyService() async {
    try {
      await _studySessionService.init();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again later.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _taskPageController.dispose();
    super.dispose();
  }

  Widget buildTaskManager(
      StudySessionModel sessionModel, ThemeProvider themeProvider) {
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
                _buildTaskListCard(sessionModel, themeProvider),
                SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          themeProvider.appContentBackgroundColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: themeProvider.iconColor),
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
          ),
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
            Text(
              'No tasks added yet.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: themeProvider.secondaryTextColor,
              ),
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

  Widget buildDefaultList(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todo',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: themeProvider.mainTextColor,
          ),
        ),
        const SizedBox(height: 16),
        if (_isAnonymous && !_dismissedAnonWarning)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: themeProvider.warningBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeProvider.warningBorderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 20, color: themeProvider.warningIconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tasks won't be saved unless you're logged in.",
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.warningTextColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: themeProvider.warningTextColor),
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
              buildPopupMenuButton(themeProvider),
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
                    _uncompletedTodoItems =
                        _uncompletedTodoItems!.where((i) => i.id != id).toList();
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _todoLists == null
        ? Shimmer.fromColors(
            baseColor: themeProvider.isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[300]!,
            highlightColor: themeProvider.isDarkMode
                ? Colors.grey[700]!
                : Colors.grey[100]!,
            child: Container(
              height: MediaQuery.of(context).size.height - kControlBarHeight,
              width: 400,
              color: themeProvider.isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[300],
            ),
          )
        : SizedBox(
            width: 400,
            height: MediaQuery.of(context).size.height - kControlBarHeight,
            child: Column(
              children: [
                buildTopBar(themeProvider),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          themeProvider.appBackgroundGradientStart,
                          themeProvider.appBackgroundGradientEnd,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(15.0),
                    child: studySession.isActive
                        ? buildTaskManager(studySession, themeProvider)
                        : buildDefaultList(themeProvider),
                  ),
                ),
              ],
            ),
          );
  }

  PopupMenuButton<dynamic> buildPopupMenuButton(ThemeProvider themeProvider) {
    return PopupMenuButton<dynamic>(
      color: themeProvider.popupBackgroundColor,
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
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.mainTextColor)),
        ),
        PopupMenuItem<SortBy>(
          value: SortBy.dueDate,
          child: Row(
            children: [
              if (_selectedSortOption == SortBy.dueDate)
                Icon(Icons.check, size: 16, color: themeProvider.iconColor),
              const SizedBox(width: 8),
              Text('Due Date',
                  style: TextStyle(color: themeProvider.mainTextColor)),
            ],
          ),
        ),
        PopupMenuItem<SortBy>(
          value: SortBy.createdAt,
          child: Row(
            children: [
              if (_selectedSortOption == SortBy.createdAt)
                Icon(Icons.check, size: 16, color: themeProvider.iconColor),
              const SizedBox(width: 8),
              Text('Created At',
                  style: TextStyle(color: themeProvider.mainTextColor)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Text('Filter By',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.mainTextColor)),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.none,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.none)
                Icon(Icons.check, size: 16, color: themeProvider.iconColor),
              const SizedBox(width: 8),
              Text('None', style: TextStyle(color: themeProvider.mainTextColor)),
            ],
          ),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.hasDueDate,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.hasDueDate)
                Icon(Icons.check, size: 16, color: themeProvider.iconColor),
              const SizedBox(width: 8),
              Text('Has Due Date',
                  style: TextStyle(color: themeProvider.mainTextColor)),
            ],
          ),
        ),
        PopupMenuItem<TodoFilter>(
          value: TodoFilter.priority,
          child: Row(
            children: [
              if (_selectedFilterOption == TodoFilter.priority)
                Icon(Icons.check, size: 16, color: themeProvider.iconColor),
              const SizedBox(width: 8),
              Text('Priority',
                  style: TextStyle(color: themeProvider.mainTextColor)),
            ],
          ),
        ),
      ],
      icon: Icon(Icons.more_horiz, color: themeProvider.iconColor),
      iconSize: 25,
    );
  }

  Widget buildTopBar(ThemeProvider themeProvider) {
    return Container(
      height: 40,
      color: themeProvider.appContentBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: themeProvider.iconColor),
          ),
        ],
      ),
    );
  }
}