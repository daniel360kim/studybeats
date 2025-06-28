import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/studyroom/study_tools/todo/todo_inputs.dart';
import 'package:studybeats/theme_provider.dart';

class TodoAdder extends StatefulWidget {
  final ValueChanged<Set<SessionTodoReference>> onTodoItemToggled;
  final Set<SessionTodoReference>? initialSelectedTodoItems;

  const TodoAdder({
    super.key,
    required this.onTodoItemToggled,
    this.initialSelectedTodoItems,
  });

  @override
  State<TodoAdder> createState() => _TodoAdderState();
}

class _TodoAdderState extends State<TodoAdder> {
  final _todoService = TodoService();
  final _todoListService = TodoListService();

  List<dynamic>? _todoLists;
  List<TodoItem>? _uncompletedTodoItems;

  Set<SessionTodoReference> _selectedTodoItems = {};
  String? _selectedListId;

  final ScrollController _internalScrollController = ScrollController();
  bool _creatingNewTask = false;
  String _searchQuery = "";
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _fetchTodoItems();
    _selectedTodoItems = widget.initialSelectedTodoItems ?? {};
  }

  @override
  void dispose() {
    _internalScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeading(themeProvider),
          const SizedBox(height: 10),
          Divider(
            color: themeProvider.dividerColor,
            height: 1,
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            switchInCurve: Curves.fastLinearToSlowEaseIn,
            switchOutCurve: Curves.fastLinearToSlowEaseIn,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.5, 0),
                end: const Offset(0, 0),
              ).animate(animation),
              child: _showSearchBar
                  ? buildSearchBarWithClose(themeProvider)
                  : buildControlButtons(themeProvider),
            ),
            child: _showSearchBar
                ? buildSearchBarWithClose(themeProvider)
                : buildControlButtons(themeProvider),
          ),
          buildAddTask(),
          const SizedBox(height: 10),
          buildTaskAdderList(themeProvider),
        ],
      ),
    );
  }

  Widget buildHeading(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add tasks',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: themeProvider.mainTextColor),
        ),
        const SizedBox(height: 5),
        Text(
          'Create or choose tasks to your session',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: themeProvider.secondaryTextColor),
        ),
      ],
    );
  }

  Widget buildControlButtons(ThemeProvider themeProvider) {
    return Row(
      children: [
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          onPressed: () {
            setState(() {
              _creatingNewTask = !_creatingNewTask;
            });
          },
          icon: Icon(
            _creatingNewTask ? Icons.remove : Icons.add,
            color: themeProvider.iconColor,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (_showSearchBar) {
                _creatingNewTask = false;
                _searchQuery = "";
              }
            });
          },
          icon: Icon(
            Icons.search,
            color: themeProvider.iconColor,
          ),
        ),
      ],
    );
  }

  Widget buildSearchBarWithClose(ThemeProvider themeProvider) {
    return Container(
      key: const ValueKey('search_bar'),
      child: Row(
        children: [
          SizedBox(
            width: 245,
            height: 30,
            child: TextField(
              cursorColor: themeProvider.primaryAppColor,
              style: TextStyle(color: themeProvider.mainTextColor),
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.search, size: 16, color: themeProvider.iconColor),
                hintText: 'Search tasks...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: themeProvider.secondaryTextColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: themeProvider.inputBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: themeProvider.primaryAppColor, width: 2),
                ),
                contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, color: themeProvider.iconColor),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(5),
            onPressed: () {
              setState(() {
                _showSearchBar = false;
                _searchQuery = "";
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildAddTask() {
    if (_creatingNewTask) {
      return CreateNewTaskInputs(
        onCreateTask: (newTask) async {
          final newTaskRef = SessionTodoReference(
            todoId: newTask.id,
            todoListId: _selectedListId!,
          );

          _selectedTodoItems.add(newTaskRef);

          setState(() {
            if (_uncompletedTodoItems == null) {
              _uncompletedTodoItems = [newTask];
            } else {
              _uncompletedTodoItems = [
                newTask,
                ..._uncompletedTodoItems!,
              ];
            }
            _creatingNewTask = false;
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
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  List<TodoItem> get _filteredTodoItems {
    if (_uncompletedTodoItems == null) return [];
    List<TodoItem> allItems = _uncompletedTodoItems!.cast<TodoItem>();
    if (_searchQuery.isEmpty) return allItems;
    return allItems
        .where((task) =>
            task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget buildTaskAdderList(ThemeProvider themeProvider) {
    return _uncompletedTodoItems == null
        ? Column(
            children: List.generate(
              5,
              (index) => ListTile(
                leading: Shimmer.fromColors(
                    baseColor: themeProvider.isDarkMode
                        ? Colors.grey[800]!
                        : Colors.grey[300]!,
                    highlightColor: themeProvider.isDarkMode
                        ? Colors.grey[700]!
                        : Colors.grey[100]!,
                    child: const Icon(Icons.circle_outlined)),
                title: Shimmer.fromColors(
                  baseColor: themeProvider.isDarkMode
                      ? Colors.grey[800]!
                      : Colors.grey[300]!,
                  highlightColor: themeProvider.isDarkMode
                      ? Colors.grey[700]!
                      : Colors.grey[100]!,
                  child: Container(
                    width: 100,
                    height: 20,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),
          )
        : _uncompletedTodoItems!.isEmpty
            ? SizedBox(
                height: _creatingNewTask
                    ? MediaQuery.of(context).size.height - 540
                    : MediaQuery.of(context).size.height - 360,
                child: Center(
                  child: Text(
                    'No tasks yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.secondaryTextColor,
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: _creatingNewTask
                    ? MediaQuery.of(context).size.height - 540
                    : MediaQuery.of(context).size.height - 360,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var todoItem in _filteredTodoItems)
                      TodoItemTile(
                        todoItem: todoItem,
                        isItemAdded: _selectedTodoItems
                            .any((item) => item.todoId == todoItem.id),
                        isItemSelected: (isSelected) {
                          setState(() {
                            if (isSelected) {
                              _selectedTodoItems.add(SessionTodoReference(
                                todoId: todoItem.id,
                                todoListId: _selectedListId!,
                              ));
                            } else {
                              _selectedTodoItems.removeWhere((item) =>
                                  item.todoId == todoItem.id &&
                                  item.todoListId == _selectedListId);
                            }
                            widget.onTodoItemToggled(_selectedTodoItems);
                          });
                        },
                      ),
                  ],
                ),
              );
  }
}

class TodoItemTile extends StatefulWidget {
  const TodoItemTile({
    required this.todoItem,
    required this.isItemAdded,
    required this.isItemSelected,
    super.key,
  });

  final TodoItem todoItem;
  final bool isItemAdded;
  final ValueChanged<bool> isItemSelected;

  @override
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile> {
  bool _isHovering = false;
  bool _isSelected = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      _isSelected = widget.isItemAdded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
        });
      },
      child: Container(
        color: _isHovering
            ? themeProvider.primaryAppColor.withOpacity(0.05)
            : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ),
          leading: GestureDetector(
            onTap: () {
              setState(() {
                _isSelected = !_isSelected;
                widget.isItemSelected(_isSelected);
              });
            },
            child: Icon(
              _isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: _isSelected
                  ? themeProvider.primaryAppColor
                  : themeProvider.secondaryTextColor,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 250,
                child: Text(
                  widget.todoItem.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: themeProvider.mainTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.todoItem.description != null &&
                  widget.todoItem.description!.isNotEmpty)
                const SizedBox(height: 4),
              if (widget.todoItem.description != null &&
                  widget.todoItem.description!.isNotEmpty)
                Text(
                  widget.todoItem.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: themeProvider.secondaryTextColor,
                  ),
                ),
              const SizedBox(height: 6),
              if (widget.todoItem.dueDate != null)
                buildDeadlineDescription(themeProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDeadlineDescription(ThemeProvider themeProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today,
            size: 12, color: themeProvider.primaryAppColor),
        const SizedBox(width: 4),
        Text(
          _getDeadlineDescription(),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: themeProvider.primaryAppColor,
          ),
        ),
      ],
    );
  }

  String _getDeadlineDescription() {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final fullDueDate = widget.todoItem.dueDate!;
    final dueDate =
        DateTime(fullDueDate.year, fullDueDate.month, fullDueDate.day);
    final differenceInDays = dueDate.difference(nowDate).inDays;
    String day;
    if (differenceInDays < 0) {
      final absDays = differenceInDays.abs();
      day = '$absDays ${absDays == 1 ? "day" : "days"} ago';
    } else if (differenceInDays == 0) {
      day = 'Today';
    } else if (differenceInDays == 1) {
      day = 'Tomorrow';
    } else if (differenceInDays < 7) {
      day = 'In $differenceInDays days';
    } else {
      day = 'On ${dueDate.month}/${dueDate.day}';
    }

    if (widget.todoItem.dueTime == null) {
      return day;
    }
    return '$day at ${_showTimeFormatted(widget.todoItem.dueTime!)}';
  }

  String _showTimeFormatted(TimeOfDay time) {
    final amPm = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }
}