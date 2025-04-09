import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';

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

  List<TodoList>?
      _todoLists; // for later implementation when multiple lists are supported
  List<TodoItem>? _uncompletedTodoItems;

  String?
      _selectedListId; // for later implementation when multiple lists are supported

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTodoItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    return ListView(
      shrinkWrap: true,
    controller: widget.scrollController,
      children: _uncompletedTodoItems?.map((todoItem) {
            final bool isItemAdded =
                widget.selectedTodoItemIds.contains(todoItem.id);
            return TodoItemTile(
              todoItem: todoItem,
              isItemAdded: isItemAdded,
              onItemAdded: () {
                widget.onTodoItemToggled(todoItem, !isItemAdded);
              },
            );
          }).toList() ??
          [],
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
          leading: GestureDetector(
            onTap: widget.onItemAdded,
            child: Icon(
              widget.isItemAdded ? Icons.check_circle : Icons.circle_outlined,
              color: widget.isItemAdded ? kFlourishAdobe : kFlourishBlackish,
            ),
          ),
          title: Text(
            widget.todoItem.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: kFlourishBlackish,
            ),
          ),
        ),
      ),
    );
  }
}
