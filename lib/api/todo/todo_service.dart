import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/log_printer.dart';

class TodoListService {
  final _authService = AuthService();
  final _logger = getLogger('TodoListService');

  late final CollectionReference<Map<String, dynamic>> _todoListCollection;

  // Client code should check and handle user not being logged in before calling this method
  Future<void> init() async {
    try {
      final email = await _getUserEmail();
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _todoListCollection = userDoc.collection('todoLists');

      // If there are no todo lists, create the default one
      final todoLists = await fetchTodoLists();
      if (todoLists.isEmpty) {
        await createEmptyTodoList();
      }
    } catch (e, s) {
      _logger.e('Failed to initialize todo service: $e $s');
      rethrow;
    }
  }

  Future<String> _getUserEmail() async {
    try {
      final email = await _authService.getCurrentUserEmail();
      if (email != null) {
        return email;
      } else {
        _logger.e('User email is null');
        throw Exception('User email is null');
      }
    } catch (e, s) {
      _logger.e('Failed to get user email: $e $s');
      rethrow;
    }
  }

  Future<void> createEmptyTodoList() async {
    try {
      _logger.i('Creating empty todo list');
      final id = _todoListCollection.doc().id;
      final emptyList = TodoList(
        id: id,
        name: 'My List',
        themeColor: Colors.blue.value.toRadixString(16),
        dateCreated: DateTime.now(),
        categories: TodoCategories(completed: [], uncompleted: []),
      );
      await createTodoList(emptyList);
    } catch (e, s) {
      _logger.e('Failed to create empty todo list: $e $s');
      rethrow;
    }
  }

  Future<void> createTodoList(TodoList todoList) async {
    try {
      _logger.i('Creating todo list: ${todoList.name}');
      await _todoListCollection.doc(todoList.id).set(todoList.toJson());
    } catch (e, s) {
      _logger.e('Failed to create todo list: $e $s');
      rethrow;
    }
  }

  Future<List<TodoList>> fetchTodoLists() async {
    try {
      _logger.i('Fetching todo lists');
      final querySnapshot = await _todoListCollection.get();
      if (querySnapshot.docs.isEmpty) {
        await createEmptyTodoList();
        return fetchTodoLists();
      }
      return querySnapshot.docs
          .map((doc) => TodoList.fromJson(doc.data()))
          .toList();
    } catch (e, s) {
      _logger.e('Failed to fetch todo lists: $e $s');
      rethrow;
    }
  }

  Future<String> getDefaultTodoListId() async {
    try {
      final todoLists = await fetchTodoLists();
      if (todoLists.isEmpty) {
        throw Exception('No todo lists available');
      }
      return todoLists.first.id;
    } catch (e, s) {
      _logger.e('Failed to get default todo list id: $e $s');
      rethrow;
    }
  }
}

class TodoService {
  final _authService = AuthService();
  final _logger = getLogger('TodoService');

  late final CollectionReference<Map<String, dynamic>> _todoCollection;

  late final Future<void> _initialization = _initialize();

  Future<void> init() => _initialization;

  Future<void> _initialize() async {
    try {
      final email = await _getUserEmail();
      if (email == null) {
        _logger.w('User email is null, skipping initialization');
        return;
      }
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _todoCollection = userDoc.collection('todoLists');
    } catch (e, s) {
      _logger.e('Failed to initialize todo service: $e $s');
      rethrow;
    }
  }

  Future<String>? _getUserEmail() async {
    try {
      final email = await _authService.getCurrentUserEmail();
      return email;
    } catch (e, s) {
      _logger.e('Failed to get user email: $e $s');
      rethrow;
    }
  }

  Future<void> addTodoItem({
    required String listId,
    required TodoItem todoItem,
  }) async {
    try {
      // Add the new todo to the list id uncompleted
      final listDoc = _todoCollection.doc(listId);

      await listDoc.update({
        'categories.uncompleted': FieldValue.arrayUnion([todoItem.toJson()]),
      });

      _logger.i('Todo item added successfully');
    } catch (e, s) {
      _logger.e('Failed to add todo item: $e $s');
      rethrow;
    }
  }

  Future<void> markTodoItemAsDone({
    required String listId,
    required String todoItemId,
  }) async {
    try {
      _logger.i('Marking todo item as done');

      final listDoc = _todoCollection.doc(listId);
      final todoListSnapshot = await listDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      final uncompleted = todoList.categories.uncompleted;
      final completed = todoList.categories.completed;

      final index = uncompleted.indexWhere((item) => item.id == todoItemId);
      if (index == -1) {
        // Check if already in completed list
        final alreadyCompleted = completed.any((item) => item.id == todoItemId);
        if (alreadyCompleted) {
          _logger.w(
              'Todo item $todoItemId is already marked as done. No action taken.');
          return;
        } else {
          _logger.w(
              'Todo item $todoItemId not found in uncompleted list. Cannot mark as done.');
          return;
        }
      }

      final todoItem = uncompleted[index];
      uncompleted.removeAt(index);
      completed.add(todoItem);

      // Delete the idea from uncompleted in firestore
      await listDoc.update({
        'categories.uncompleted': FieldValue.arrayRemove(
            [Map<String, dynamic>.from(todoItem.toJson())]),
        'categories.completed': FieldValue.arrayUnion(
            [Map<String, dynamic>.from(todoItem.toJson())]),
      });

      _logger.i('Todo item marked as done successfully');
    } catch (e, s) {
      _logger.e('Failed to mark todo item as done: $e $s');
      rethrow;
    }
  }

  Future<void> markTodoItemAsUndone({
    required String listId,
    required String todoItemId,
  }) async {
    try {
      _logger.i('Marking todo item as undone');

      // Get the list document reference
      final listDoc = _todoCollection.doc(listId);

      // Fetch the document to get the current state
      final todoListSnapshot = await listDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      // Find the item to mark as undone
      final todoItem = todoList.categories.completed.firstWhere(
        (item) => item.id == todoItemId,
        orElse: () {
          throw Exception('Todo item not found in completed list');
        },
      );

      // Update Firestore: Remove from 'completed' and add to 'uncompleted'
      await listDoc.update({
        'categories.completed': FieldValue.arrayRemove(
            [Map<String, dynamic>.from(todoItem.toJson())]),
        'categories.uncompleted': FieldValue.arrayUnion(
            [Map<String, dynamic>.from(todoItem.toJson())]),
      });

      _logger.i('Todo item marked as undone successfully');
    } catch (e, s) {
      _logger.e('Failed to mark todo item as undone: $e $s');
      rethrow;
    }
  }

  Future<void> updateIncompleteTodoItem(
      {required String listId, required TodoItem updatedItem}) async {
    try {
      _logger.i('Updating todo item');

      // Get the list document reference
      final listDoc = _todoCollection.doc(listId);

      // Fetch the document to get the current state
      final todoListSnapshot = await listDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      // Find the item to update
      final todoItemIndex = todoList.categories.uncompleted.indexWhere(
        (item) => item.id == updatedItem.id,
      );

      if (todoItemIndex == -1) {
        throw Exception(
            'Failed to update incomplete item: Todo item not found in uncompleted list');
      }

      // Update Firestore: Replace the item in 'uncompleted'
      final updatedItems = List<TodoItem>.from(todoList.categories.uncompleted);
      updatedItems[todoItemIndex] = updatedItem;

      await listDoc.update({
        'categories.uncompleted': updatedItems.map((e) => e.toJson()).toList(),
      });

      _logger.i('Todo item updated successfully');
    } catch (e, s) {
      _logger.e('Failed to update todo item: $e $s');
      rethrow;
    }
  }

  Future<List<TodoItem>> fetchTodoItems(String listId) async {
    try {
      final todoListDoc = _todoCollection.doc(listId);
      final todoListSnapshot = await todoListDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      return todoList.categories.uncompleted + todoList.categories.completed;
    } catch (e, s) {
      _logger.e('Failed to fetch todo items: $e $s');
      rethrow;
    }
  }

  Future<List<TodoItem>> fetchCompletedTodoItems(String listId) async {
    try {
      final todoListDoc = _todoCollection.doc(listId);
      final todoListSnapshot = await todoListDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      return todoList.categories.completed;
    } catch (e, s) {
      _logger.e('Failed to fetch completed todo items: $e $s');
      rethrow;
    }
  }

  Future<List<TodoItem>> fetchUncompletedTodoItems(final String listId) async {
    try {
      final todoListDoc = _todoCollection.doc(listId);
      final todoListSnapshot = await todoListDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      return todoList.categories.uncompleted;
    } catch (e, s) {
      _logger.e('Failed to fetch uncompleted todo items: $e $s');
      rethrow;
    }
  }

  Future<void> deleteUncompletedItem(String listId, String itemId) async {
    try {
      _logger.i('Deleting uncompleted todo item');

      // Get the list document reference
      final listDoc = _todoCollection.doc(listId);

      // Fetch the document to get the current state
      final todoListSnapshot = await listDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      // Find the item to delete
      final todoItemIndex = todoList.categories.uncompleted.indexWhere(
        (item) => item.id == itemId,
      );

      if (todoItemIndex == -1) {
        _logger.w(
            'Todo item $itemId not found in uncompleted list. Cannot delete.');
        return;
      }

      // Update Firestore: Remove the item from 'uncompleted'
      final updatedItems = List<TodoItem>.from(todoList.categories.uncompleted);
      updatedItems.removeAt(todoItemIndex);

      await listDoc.update({
        'categories.uncompleted': updatedItems.map((e) => e.toJson()).toList(),
      });

      _logger.i('Todo item deleted successfully');
    } catch (e, s) {
      _logger
          .w('Failed to delete uncompleted todo item with id: $itemId $e $s');
    }
  }

  Stream<List<TodoItem>> streamUncompletedTodoItems(String listId) {
    try {
      final todoListDoc = _todoCollection.doc(listId);
      return todoListDoc.snapshots().map((snapshot) {
        final todoList = TodoList.fromJson(snapshot.data()!);
        return todoList.categories.uncompleted;
      });
    } catch (e, s) {
      _logger.e('Failed to stream uncompleted todo items: $e $s');
      rethrow;
    }
  }

  Future<TodoItem> getTodoItem(String listId, String itemId) async {
    try {
      final todoListDoc = _todoCollection.doc(listId);
      final todoListSnapshot = await todoListDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      return todoList.categories.uncompleted.firstWhere(
        (item) => item.id == itemId,
        orElse: () => throw Exception('Todo item not found'),
      );
    } catch (e, s) {
      _logger.e('Failed to get todo item: $e $s');
      rethrow;
    }
  }
}
