import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_inputs.dart';

class TodoAdder extends StatefulWidget {
  final void Function(TodoItem todoItem, bool isChecked) onTodoItemToggled;
  final List<String> selectedTodoItemIds;
  final ScrollController scrollController;

  const TodoAdder({
    super.key,
    required this.onTodoItemToggled,
    required this.selectedTodoItemIds,
    required this.scrollController,
  });

  @override
  State<TodoAdder> createState() => _TodoAdderState();
}

class _TodoAdderState extends State<TodoAdder> {
  final _todoService = TodoService();
  final _todoListService = TodoListService();

  List<dynamic>?
      _todoLists; // For later implementation when multiple lists are supported
  List<TodoItem>? _uncompletedTodoItems;

  String?
      _selectedListId; // For later implementation when multiple lists are supported

  final ScrollController _internalScrollController = ScrollController();

  bool _creatingNewTask = false;
  // New state variables for search functionality
  String _searchQuery = "";
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _fetchTodoItems();
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
      final uncompletedTodoItems = todoLists.first.categories.uncompleted;
      setState(() {
        _todoLists = todoLists;
        _selectedListId = todoLists.first.id;
        _uncompletedTodoItems = uncompletedTodoItems;
      });
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeading(),
          const SizedBox(height: 10),
          Divider(
            color: kFlourishBlackish.withOpacity(0.1),
            height: 1,
          ),
          const SizedBox(height: 10),
          // Use AnimatedSwitcher to show either the control buttons or the search bar.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            switchInCurve: Curves.fastLinearToSlowEaseIn,
            switchOutCurve: Curves.fastLinearToSlowEaseIn,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.5, 0), // slides in from right
                end: const Offset(0, 0),
              ).animate(animation),
              child: child,
            ),
            child: _showSearchBar
                ? buildSearchBarWithClose()
                : buildControlButtons(),
          ),
          buildAddTask(),
          const SizedBox(height: 10),
          buildTaskAdderList(),
        ],
      ),
    );
  }

  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add tasks',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kFlourishBlackish),
        ),
        const SizedBox(height: 5),
        Text(
          'Create or choose tasks to your session',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: kFlourishBlackish.withOpacity(0.5)),
        ),
      ],
    );
  }

// Modify buildControlButtons to include the search icon:
  Widget buildControlButtons() {
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
            color: kFlourishBlackish,
          ),
        ),
        const SizedBox(width: 8),
        // New search icon button:
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (_showSearchBar) {
                _creatingNewTask = false; // Hide task creation when searching
                _searchQuery = ""; // Clear search query when showing the bar
              }
            });
          },
          icon: const Icon(
            Icons.search,
            color: kFlourishBlackish,
          ),
        ),
      ],
    );
  }

  // Add a new widget method that builds the search bar:
  Widget buildSearchBarWithClose() {
    return Container(
      key: const ValueKey('search_bar'),
      child: Row(
        children: [
          SizedBox(
            width: 245,
            height: 30,
            child: TextField(
              cursorColor: kFlourishBlackish,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Search tasks...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: kFlourishBlackish.withOpacity(0.8),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: kFlourishBlackish.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: kFlourishBlackish, width: 2),
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
          // Close icon to hide search bar and revert to control buttons.
          IconButton(
            icon: const Icon(Icons.close, color: kFlourishBlackish),
            constraints: BoxConstraints(),
            padding: const EdgeInsets.all(5),
            onPressed: () {
              setState(() {
                _showSearchBar = false;
                _searchQuery = ""; // clear search query if needed.
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

// Replace the buildTaskAdderList() method in todo_adder.dart with the following:

  Widget buildTaskAdderList() {
    return _uncompletedTodoItems == null
        ? Column(
            children: List.generate(
              5,
              (index) => ListTile(
                leading: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: const Icon(Icons.circle_outlined)),
                title: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 100,
                    height: 20,
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
          )
        : SizedBox(
            height: _creatingNewTask
                ? MediaQuery.of(context).size.height - 540
                : MediaQuery.of(context).size.height - 360,
            child: ListView(
              controller: widget.scrollController,
              shrinkWrap: true,
              children: _filteredTodoItems.map((todoItem) {
                final bool isItemAdded =
                    widget.selectedTodoItemIds.contains(todoItem.id);
                return TodoItemTile(
                  todoItem: todoItem,
                  isItemAdded: isItemAdded,
                  onItemAdded: () {
                    widget.onTodoItemToggled(todoItem, !isItemAdded);
                  },
                );
              }).toList(),
            ),
          );
  }
}

class TodoItemTile extends StatefulWidget {
  const TodoItemTile({
    required this.todoItem,
    required this.isItemAdded,
    required this.onItemAdded,
    super.key,
  });

  final TodoItem todoItem;
  final bool isItemAdded;
  final VoidCallback onItemAdded;

  @override
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile> {
  bool _isHovering = false;
  @override
  Widget build(BuildContext context) {
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
            ? kFlourishLightBlackish.withOpacity(0.1)
            : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ),
          leading: GestureDetector(
            onTap: widget.onItemAdded,
            child: Icon(
              widget.isItemAdded ? Icons.check_circle : Icons.circle_outlined,
              color: widget.isItemAdded ? kFlourishAdobe : kFlourishBlackish,
            ),
          ),
          title: Row(
            children: [
              Text(
                widget.todoItem.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: kFlourishBlackish,
                ),
              ),
              const SizedBox(width: 12),
              if (widget.todoItem.dueDate != null) buildDeadlineDescription(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDeadlineDescription() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_today, size: 12, color: kFlourishAdobe),
        const SizedBox(width: 4),
        Text(
          _getDeadlineDescription(),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: kFlourishAdobe,
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
