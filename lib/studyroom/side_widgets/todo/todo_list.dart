import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/studyroom/side_widgets/todo/item_tile.dart';
import 'package:flutter/material.dart';

enum SortBy { dueDate, createdAt }

enum TodoFilter { none, priority, hasDueDate }

class TodoListWidget extends StatefulWidget {
  const TodoListWidget({
    required this.uncompleted,
    required this.sortBy,
    required this.filter,
    required this.onItemMarkedAsDone,
    required this.onItemDetailsChanged,
    super.key,
  });

  final List<TodoItem> uncompleted;
  final SortBy sortBy;
  final TodoFilter filter;
  final ValueChanged<String> onItemMarkedAsDone;
  final ValueChanged<TodoItem> onItemDetailsChanged;

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<TodoListWidget> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<TodoItem> _items;

  @override
  void initState() {
    super.initState();
    _items = _sortItems(widget.uncompleted);
  }

  @override
  void didUpdateWidget(covariant TodoListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uncompleted != widget.uncompleted) {
      // Identify differences between the old and new list
      final oldIds = oldWidget.uncompleted.map((e) => e.id).toSet();
      final newIds = widget.uncompleted.map((e) => e.id).toSet();

      // Handle removed items
      final removedItems = oldIds.difference(newIds);
      for (final id in removedItems) {
        final index = _items.indexWhere((item) => item.id == id);
        if (index != -1) {
          _removeItem(index);
        }
      }

      // Handle added items
      final addedItems = widget.uncompleted
          .where((item) => !oldIds.contains(item.id))
          .toList();
      for (final item in addedItems) {
        _items.add(item);
        _listKey.currentState?.insertItem(_items.length - 1);
      }

      // Re-sort the list
      _items = _sortItems(_items);
    }
  }

  List<TodoItem> _sortItems(List<TodoItem> items) {
    switch (widget.sortBy) {
      case SortBy.dueDate:
        return items
          ..sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1; // Nulls go last
            if (b.dueDate == null) return -1;
            return a.dueDate!.compareTo(b.dueDate!);
          });
      case SortBy.createdAt:
        return items..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  void _removeItem(int index) {
    final removedItem = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildRemovedItem(removedItem, animation),
    );

    widget.onItemMarkedAsDone(removedItem.id);
  }

  Widget _buildRemovedItem(TodoItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: TodoItemTile(
        item: item,
        onItemMarkedAsDone: () {},
        onItemDetailsChanged: (value) {},
        onPriorityChanged: (value) {},
        onItemDateTimeChanged: (value) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ANimated list and also filter the items
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) {
        final item = _items[index];
        if (widget.filter == TodoFilter.priority && !item.isFavorite) {
          return const SizedBox.shrink();
        }
        if (widget.filter == TodoFilter.hasDueDate && item.dueDate == null) {
          return const SizedBox.shrink();
        }
        return SizeTransition(
          sizeFactor: animation,
          child: TodoItemTile(
            item: item,
            onItemMarkedAsDone: () => _removeItem(index),
            onItemDetailsChanged: (value) => widget.onItemDetailsChanged(value),
            onItemDateTimeChanged: (value) =>
                widget.onItemDetailsChanged(value),
            onPriorityChanged: (value) {},
          ),
        );
      },
    );
  }
}
