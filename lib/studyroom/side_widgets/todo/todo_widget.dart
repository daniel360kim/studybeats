import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';

import 'package:studybeats/studyroom/side_widgets/todo/todo_inputs.dart';
import 'package:studybeats/studyroom/side_widgets/todo/todo_list.dart';
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
  List<TodoList>? _todoLists;
  List<TodoItem>? _uncompletedTodoItems;
  bool _creatingNewTask = false;
  SortBy _selectedSortOption = SortBy.dueDate;
  TodoFilter _selectedFilterOption = TodoFilter.none;

  @override
  void initState() {
    super.initState();
    _fetchTodoItems();
  }

  void _fetchTodoItems() async {
    try {
      await _todoService.init();
      final todoLists = await _todoService.fetchTodoLists();
      final uncompletedTodoItems = todoLists.first.categories.uncompleted;
      setState(() {
        _todoLists = todoLists;

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
    return _todoLists == null
        ? Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: MediaQuery.of(context).size.height - 80,
              width: 400,
              color: Colors.white,
            ),
          )
        : SizedBox(
            width: 400,
            height: MediaQuery.of(context).size.height - 80,
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
                    child: Column(
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
                                final listId =
                                    await _todoService.getDefaultTodoListId();
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
                            _uncompletedTodoItems!.isNotEmpty)
                          Expanded(
                            child: TodoListWidget(
                                sortBy: _selectedSortOption,
                                filter: _selectedFilterOption,
                                key: ValueKey(_selectedSortOption),
                                uncompleted: _uncompletedTodoItems ?? [],
                                onItemMarkedAsDone: (itemId) async {
                                  try {
                                    await _todoService.markTodoItemAsDone(
                                      listId: _todoLists!.first.id,
                                      todoItemId: itemId,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to mark item as done: $e'),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _uncompletedTodoItems!.removeWhere(
                                        (element) => element.id == itemId);
                                  });
                                },
                                onItemDetailsChanged: (item) async {
                                  // Update the item details
                                  try {
                                    await _todoService.updateIncompleteTodoItem(
                                        listId: _todoLists!.first.id,
                                        updatedItem: item);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to update item details: $e'),
                                      ),
                                    );
                                  }

                                  setState(() {
                                    final index = _uncompletedTodoItems!
                                        .indexWhere(
                                            (element) => element.id == item.id);
                                    _uncompletedTodoItems![index] = item;
                                  });
                                }),

                            // Show snack bar on completed with undo option
                          )
                      ],
                    ),
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
