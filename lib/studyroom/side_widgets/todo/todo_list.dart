import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studybeats/api/todo/todo_item.dart'; // Your TodoItem model.
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/todo/item_tile.dart'; // Your tile widget.

// Sorting and filtering enums.
enum SortBy { dueDate, createdAt }

enum TodoFilter { none, priority, hasDueDate }

class TodoListWidget extends StatefulWidget {
  const TodoListWidget({
    required this.uncompletedStream,
    required this.sortBy,
    required this.filter,
    required this.onItemMarkedAsDone,
    required this.onItemDetailsChanged,
    required this.onItemDelete,
    super.key,
  });

  final Stream<List<TodoItem>> uncompletedStream;
  final SortBy sortBy;
  final TodoFilter filter;
  final ValueChanged<String> onItemMarkedAsDone;
  final ValueChanged<TodoItem> onItemDetailsChanged;
  final ValueChanged<String> onItemDelete;

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<TodoListWidget> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<TodoItem> _items = [];
  StreamSubscription<List<TodoItem>>? _subscription;
  String? _editingItemId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.uncompletedStream.listen((newItems) {
      final sortedNewItems = _sortItems(newItems);
      _updateList(sortedNewItems);
    });
  }

  @override
  void didUpdateWidget(covariant TodoListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uncompletedStream != widget.uncompletedStream) {
      _subscription?.cancel();
      _subscription = widget.uncompletedStream.listen((newItems) {
        final sortedNewItems = _sortItems(newItems);
        _updateList(sortedNewItems);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<TodoItem> _sortItems(List<TodoItem> items) {
    final sorted = List<TodoItem>.from(items);
    sorted.sort((a, b) {
      if (a.id == _editingItemId) return -1;
      if (b.id == _editingItemId) return 1;
      switch (widget.sortBy) {
        case SortBy.dueDate:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        case SortBy.createdAt:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
    return sorted;
  }

  void _updateList(List<TodoItem> newItems) {
    final newItemsMap = {for (var item in newItems) item.id: item};

    // Remove items no longer present.
    for (int i = _items.length - 1; i >= 0; i--) {
      if (!newItemsMap.containsKey(_items[i].id)) {
        final removedItem = _items.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildRemovedItem(removedItem, animation),
          duration: const Duration(milliseconds: 300),
        );
        widget.onItemDelete(removedItem.id);
      }
    }

    // Insert or update items.
    for (int i = 0; i < newItems.length; i++) {
      final newItem = newItems[i];
      final existingIndex = _items.indexWhere((item) => item.id == newItem.id);
      if (existingIndex == -1) {
        _items.insert(i, newItem);
        _listKey.currentState
            ?.insertItem(i, duration: const Duration(milliseconds: 300));
      } else {
        _items[existingIndex] = newItem;
        if (existingIndex != i) {
          final item = _items.removeAt(existingIndex);
          _listKey.currentState?.removeItem(
            existingIndex,
            (context, animation) => _buildRemovedItem(item, animation),
            duration: const Duration(milliseconds: 300),
          );
          _items.insert(i, newItem);
          _listKey.currentState
              ?.insertItem(i, duration: const Duration(milliseconds: 300));
        }
      }
    }
  }

  Widget _buildRemovedItem(TodoItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: TodoItemTile(
        key: ValueKey(item.id),
        item: item,
        isEditing: false,
        onEditStart: () {},
        onEditEnd: () {},
        onItemMarkedAsDone: () {},
        onItemDetailsChanged: (value) {},
        onItemDateTimeChanged: (value) {},
        onItemDelete: () {},
      ),
    );
  }

  /// Optimistically marks an item as done with undo support.
  void _handleMarkAsDone(int index) {
    // Capture the removed item.
    final removedItem = _items[index];

    // Remove the item immediately from the UI.
    _removeItem(index);

    // Show a SnackBar with an UNDO option.
    final snackBar = SnackBar(
      content: Text('Item completed', style: TextStyle(color: Colors.white)),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          // If undo is pressed, reinsert the item.
          setState(() {
            final undoneRemovedItem = removedItem.copyWith(isDone: false);
            _items.insert(index, undoneRemovedItem);
            _listKey.currentState?.insertItem(
              index,
              duration: const Duration(milliseconds: 300),
            );
          });
        },
        textColor: kFlourishAdobe,
      ),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, // Makes it smaller in width
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded edges
      ),
      margin: const EdgeInsets.symmetric(
          horizontal: 50, vertical: 10), // Reduce width
      backgroundColor: kFlourishBlackish, // Customize background
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((reason) {
      // If the SnackBar was dismissed without undo, perform the final deletion.
      if (reason != SnackBarClosedReason.action) {
        widget.onItemMarkedAsDone(removedItem.id);
      }
    });
  }

  /// Remove an item by index and animate its removal.
  TodoItem _removeItem(int index) {
    final removedItem = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildRemovedItem(removedItem, animation),
      duration: const Duration(milliseconds: 300),
    );
    return removedItem;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) {
        final item = _items[index];

        // Apply filtering.
        if (widget.filter == TodoFilter.priority && !item.isFavorite) {
          return const SizedBox.shrink();
        }
        if (widget.filter == TodoFilter.hasDueDate && item.dueDate == null) {
          return const SizedBox.shrink();
        }

        return SizeTransition(
          key: ValueKey(item.id),
          sizeFactor: animation,
          child: TodoItemTile(
            key: ValueKey(item.id),
            item: item,
            isEditing: item.id == _editingItemId,
            onEditStart: () {
              setState(() {
                _editingItemId = item.id;
              });
            },
            onEditEnd: () {
              setState(() {
                _editingItemId = null;
              });
            },
            // Use our optimistic update handler.
            onItemMarkedAsDone: () {
              _handleMarkAsDone(index);
            },
            onItemDetailsChanged: widget.onItemDetailsChanged,
            onItemDateTimeChanged: widget.onItemDetailsChanged,
            onItemDelete: () {
              final removedItem = _removeItem(index);
              widget.onItemDelete(removedItem.id);
            },
          ),
        );
      },
    );
  }
}
