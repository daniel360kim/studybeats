import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studybeats/api/todo/todo_item.dart'; // Your TodoItem model.
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

  // Track the id of the item currently being edited.
  String? _editingItemId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.uncompletedStream.listen((newItems) {
      // Sort the new items.
      final sortedNewItems = _sortItems(newItems);
      // Update our AnimatedList.
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

  /// Sorts items based on the widget.sortBy setting.
  /// If an item is in editing mode, its order is not disturbed.
  List<TodoItem> _sortItems(List<TodoItem> items) {
    final sorted = List<TodoItem>.from(items);
    sorted.sort((a, b) {
      // If one of the items is being edited, keep it in place.
      if (a.id == _editingItemId) return -1;
      if (b.id == _editingItemId) return 1;
      // Otherwise, sort normally.
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

  /// Diff the new list with our current _items list and animate removals and insertions.
  void _updateList(List<TodoItem> newItems) {
    // Build a map for quick lookup of new items by id.
    final newItemsMap = {for (var item in newItems) item.id: item};

    // Remove items that no longer exist.
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

    // Process each new item in order.
    for (int i = 0; i < newItems.length; i++) {
      final newItem = newItems[i];
      final existingIndex = _items.indexWhere((item) => item.id == newItem.id);
      if (existingIndex == -1) {
        // The item is new, so insert it.
        _items.insert(i, newItem);
        _listKey.currentState
            ?.insertItem(i, duration: const Duration(milliseconds: 300));
      } else {
        // Update the existing item.
        _items[existingIndex] = newItem;
        // Optionally, if the item’s position has changed, consider moving it.
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

  /// Build a tile for an item that is being removed.
  Widget _buildRemovedItem(TodoItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: TodoItemTile(
        key: ValueKey(item.id),
        item: item,
        // For removed items we can disable editing.
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

  /// Remove an item by index.
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

        // Apply filtering as needed.
        if (widget.filter == TodoFilter.priority && !item.isFavorite) {
          return const SizedBox.shrink();
        }
        if (widget.filter == TodoFilter.hasDueDate && item.dueDate == null) {
          return const SizedBox.shrink();
        }

        // Wrap each item in a SizeTransition for animation.
        return SizeTransition(
          key: ValueKey(item.id),
          sizeFactor: animation,
          child: TodoItemTile(
              key: ValueKey(item.id),
              item: item,
              // Mark this tile as editing if its id matches our _editingItemId.
              isEditing: item.id == _editingItemId,
              // When editing starts, record the item’s id.
              onEditStart: () {
                setState(() {
                  _editingItemId = item.id;
                });
              },
              // When editing ends, clear the editing state.
              onEditEnd: () {
                setState(() {
                  _editingItemId = null;
                });
              },
              // When the user marks the item as done, remove it.
              onItemMarkedAsDone: () {
                final removedItem = _removeItem(index);
                widget.onItemMarkedAsDone(removedItem.id);
              },
              onItemDetailsChanged: widget.onItemDetailsChanged,
              onItemDateTimeChanged: widget.onItemDetailsChanged,
              onItemDelete: () {
                final removedItem = _removeItem(index);
                widget.onItemDelete(removedItem.id);
              }),
        );
      },
    );
  }
}
