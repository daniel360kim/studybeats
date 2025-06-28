import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/theme_provider.dart';

class SessionTaskList extends StatefulWidget {
  const SessionTaskList(
      {required this.todoIds, this.taskListVisibleLength = 3, super.key});

  final Set<SessionTodoReference> todoIds;
  final int taskListVisibleLength;

  @override
  State<SessionTaskList> createState() => _SessionTaskListState();
}

class _SessionTaskListState extends State<SessionTaskList> {
  List<TodoItem> todoItems = [];
  final List<SessionTodoReference> _todoRefs = [];
  final TodoService _todoService = TodoService();
  final TodoListService _todoListService = TodoListService();

  final _logger = getLogger('Dialog Session Task List');
  static const double _tileHeight = 50.0;

  @override
  void initState() {
    super.initState();
    initTodos();
  }

  void initTodos() async {
    try {
      await _todoService.init();
      await _todoListService.init();
      for (var todoRef in widget.todoIds) {
        TodoItem todoItem =
            await _todoService.getTodoItem(todoRef.todoListId, todoRef.todoId);
        if (mounted) {
          setState(() {
            todoItems.add(todoItem);
            _todoRefs.add(todoRef);
          });
        }
      }
    } catch (e) {
      _logger.e('Failed to fetch todos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (todoItems.isEmpty) {
      return Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Shimmer.fromColors(
              baseColor: themeProvider.isDarkMode
                  ? Colors.grey[800]!
                  : Colors.grey.shade300,
              highlightColor: themeProvider.isDarkMode
                  ? Colors.grey[700]!
                  : Colors.grey.shade100,
              child: Container(
                height: _tileHeight,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height - 310,
      child: ListView.builder(
        itemCount: todoItems.length,
        itemBuilder: (context, index) {
          final todoItem = todoItems[index];
          final ref = _todoRefs[index];
          return SessionTaskTile(
            todoItem: todoItem,
            onToggleDone: (checked) async {
              try {
                if (checked == true) {
                  await _todoService.updateIncompleteTodoItem(
                    listId: ref.todoListId,
                    updatedItem: todoItem.copyWith(isDone: true),
                  );
                  setState(() {
                    todoItem.isDone = true;
                    todoItems.removeAt(index);
                    todoItems.add(todoItem);
                  });
                } else {
                  await _todoService.updateIncompleteTodoItem(
                      listId: ref.todoListId,
                      updatedItem: todoItem.copyWith(isDone: false));
                  setState(() {
                    todoItem.isDone = false;
                    todoItems.removeAt(index);
                    todoItems.insert(0, todoItem);
                  });
                }
              } catch (e) {
                _logger.e('Failed to toggle todo item: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update task. Please try again.'),
                    ),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }
}

class SessionTaskTile extends StatefulWidget {
  final TodoItem todoItem;
  final ValueChanged<bool?> onToggleDone;

  const SessionTaskTile({
    super.key,
    required this.todoItem,
    required this.onToggleDone,
  });

  @override
  State<SessionTaskTile> createState() => _SessionTaskTileState();
}

class _SessionTaskTileState extends State<SessionTaskTile> {
  bool _isHovering = false;
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
        height: _SessionTaskListState._tileHeight,
        color: _isHovering
            ? themeProvider.primaryAppColor.withOpacity(0.05)
            : Colors.transparent,
        child: ListTile(
          leading: Checkbox(
            value: widget.todoItem.isDone,
            onChanged: widget.onToggleDone,
            activeColor: themeProvider.primaryAppColor,
          ),
          title: Text(
            widget.todoItem.title,
            style: TextStyle(
              decoration:
                  widget.todoItem.isDone ? TextDecoration.lineThrough : null,
              color: widget.todoItem.isDone
                  ? themeProvider.secondaryTextColor
                  : themeProvider.mainTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
