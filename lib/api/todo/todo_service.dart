import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/log_printer.dart';
import 'package:flutter/material.dart';

class TodoService {
  final _authService = AuthService();
  final _logger = getLogger('TodoService');

  late final CollectionReference<Map<String, dynamic>> _todoCollection;


  Future<void> init() async {
    try {
    final email = await _getUserEmail();
    final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
    _todoCollection = userDoc.collection('todoLists');

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
      final id = _todoCollection.doc().id;
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
      await _todoCollection.doc(todoList.id).set(todoList.toJson());
    } catch (e, s) {
      _logger.e('Failed to create todo list: $e $s');
      rethrow;
    }
  }

  Future<List<TodoList>> fetchTodoLists() async {
    try {
      _logger.i('Fetching todo lists');
      final querySnapshot = await _todoCollection.get();
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

      // Get the list document reference
      final listDoc = _todoCollection.doc(listId);

      // Fetch the document to get the current state
      final todoListSnapshot = await listDoc.get();
      final todoList = TodoList.fromJson(todoListSnapshot.data()!);

      // Find the item to mark as done
      final todoItem = todoList.categories.uncompleted.firstWhere(
        (item) => item.id == todoItemId,
        orElse: () {
          throw Exception('Todo item not found in uncompleted list');
        },
      );

      // Update Firestore: Remove from 'uncompleted' and add to 'completed'
      await listDoc.update({
        'categories.uncompleted': FieldValue.arrayRemove([todoItem.toJson()]),
        'categories.completed': FieldValue.arrayUnion([todoItem.toJson()]),
      });

      _logger.i('Todo item marked as done successfully');
    } catch (e, s) {
      _logger.e('Failed to mark todo item as done: $e $s');
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
        throw Exception('Todo item not found in uncompleted list');
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

  Future<List<TodoItem>> fetchUncompletedTodoItems() async {
    try {
      final listId = (await fetchTodoLists()).first.id;
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
        throw Exception('Todo item not found in uncompleted list');
      }

      // Update Firestore: Remove the item from 'uncompleted'
      final updatedItems = List<TodoItem>.from(todoList.categories.uncompleted);
      updatedItems.removeAt(todoItemIndex);

      await listDoc.update({
        'categories.uncompleted': updatedItems.map((e) => e.toJson()).toList(),
      });

      _logger.i('Todo item deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete uncompleted todo item: $e $s');
      rethrow;
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
}
