import 'package:flutter/material.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';

class TodoAdder extends StatefulWidget {
  const TodoAdder({super.key});

  @override
  State<TodoAdder> createState() => _TodoAdderState();
}

class _TodoAdderState extends State<TodoAdder> {
  final _todoService = TodoService();
  final _todoListService = TodoListService();

  List<TodoList>? _todoLists;
  List<TodoItem>? _uncompletedTodoItems;

  String? _selectedListId;

  bool _creatingNewTask = false;

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

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
