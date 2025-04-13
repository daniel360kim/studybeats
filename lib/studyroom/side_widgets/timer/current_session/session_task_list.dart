import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';

class SessionTaskList extends StatefulWidget {
  const SessionTaskList({required this.todoIds, super.key});

  final List<String> todoIds;

  @override
  State<SessionTaskList> createState() => _SessionTaskListState();
}

class _SessionTaskListState extends State<SessionTaskList> {
  List<TodoItem> todoItems = [];
  final TodoService _todoService = TodoService();
  final TodoListService _todoListService = TodoListService();

  String? _todoListId;

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
      final todoLists = await _todoListService.fetchTodoLists();
      final todoListId = todoLists.first.id;
      for (var todoId in widget.todoIds) {
        TodoItem todoItem = await _todoService.getTodoItem(todoListId, todoId);
        setState(() {
          _todoListId = todoListId;
          todoItems.add(todoItem);
        });
      }
    } catch (e) {
      // Handle error
      _logger.e('Failed to fetch todos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (todoItems.isEmpty || _todoListId == null) {
      return Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: _tileHeight,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: _tileHeight *
          (todoItems.length < 3
              ? todoItems.length
              : 3), // Adjust height based on item count
      child: ListView.builder(
        itemCount: todoItems.length,
        itemBuilder: (context, index) {
          final todoItem = todoItems[index];
          // Locate the onToggleDone callback in your ListView.builder:
          return SessionTaskTile(
            todoItem: todoItem,
            onToggleDone: (checked) async {
              try {
                if (checked == true) {
                  await _todoService.markTodoItemAsDone(
                    listId: _todoListId!,
                    todoItemId: todoItem.id,
                  );
                  // Optimistically mark as done.
                  setState(() {
                    todoItem.isDone = true;
                  });
                  // Delay reordering to allow the user to see the state change.
                  await Future.delayed(const Duration(milliseconds: 500));
                  setState(() {
                    todoItems.removeAt(index);
                    todoItems.add(todoItem);
                  });
                } else {
                  await _todoService.markTodoItemAsUndone(
                    listId: _todoListId!,
                    todoItemId: todoItem.id,
                  );
                  setState(() {
                    todoItem.isDone = false;
                    todoItems.removeAt(index);
                    todoItems.insert(0, todoItem);
                  });
                }
              } catch (e) {
                _logger.e('Failed to toggle todo item: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update task. Please try again.'),
                  ),
                );
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
    Key? key,
    required this.todoItem,
    required this.onToggleDone,
  }) : super(key: key);

  @override
  State<SessionTaskTile> createState() => _SessionTaskTileState();
}

class _SessionTaskTileState extends State<SessionTaskTile> {
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
        height: _SessionTaskListState._tileHeight,
        color: _isHovering
            ? Colors.grey.shade200
            : kFlourishAliceBlue.withOpacity(0.8),
        child: ListTile(
          leading: Checkbox(
            value: widget.todoItem.isDone,
            onChanged: widget.onToggleDone,
            activeColor: kFlourishAdobe,
          ),
          title: Text(
            widget.todoItem.title,
            style: TextStyle(
              decoration:
                  widget.todoItem.isDone ? TextDecoration.lineThrough : null,
              color: widget.todoItem.isDone ? Colors.grey : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
