import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

TimeOfDay _parseTimeOfDay(String time) {
  final parts = time.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

TodoItem todoItemFromJson(Map<String, dynamic> json) {
  return TodoItem(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    isDone: json['isDone'],
    isFavorite: json['isFavorite'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    dueTime: json['dueTime'] != null ? _parseTimeOfDay(json['dueTime']) : null,
  );
}

@JsonSerializable()
class TodoItem {
  String id;
  String title;
  String? description;
  bool isDone;
  bool isFavorite;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? dueDate;
  TimeOfDay? dueTime;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isDone,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    required this.dueDate,
    required this.dueTime,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      todoItemFromJson(json);

  // Copy with 
  TodoItem copyWith({
    String? id,
    String? title,
    String? description,
    bool? isDone,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    TimeOfDay? dueTime,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isDone': isDone,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime != null ? _convertTimeOfDay(dueTime!) : null,
    };
  }

  String _convertTimeOfDay(TimeOfDay time) {
    return '${time.hour}:${time.minute}';
  }
}

class TodoCategories {
  final List<TodoItem> completed;
  final List<TodoItem> uncompleted;

  TodoCategories({
    required this.completed,
    required this.uncompleted,
  });

  factory TodoCategories.fromJson(Map<String, dynamic> json) {
    return TodoCategories(
      completed: (json['completed'] as List<dynamic>?)
              ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [], // Fallback to an empty list if the 'completed' key is null or not a List
      uncompleted: (json['uncompleted'] as List<dynamic>?)
              ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [], // Fallback to an empty list if the 'uncompleted' key is null or not a List
    );
  }
}

@JsonSerializable()
class TodoList {
  final String id;
  final String name;
  final String themeColor;
  final DateTime dateCreated;
  final TodoCategories categories;

  TodoList({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.dateCreated,
    required this.categories,
  });

  factory TodoList.fromJson(Map<String, dynamic> json) {
    return TodoList(
      id: json['id'] as String,
      name: json['name'] as String,
      themeColor: json['themeColor'] as String,
      dateCreated: DateTime.parse(json['dateCreated']),
      categories: TodoCategories.fromJson(json['categories']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'themeColor': themeColor,
      'dateCreated': dateCreated.toIso8601String(),
      'categories': {
        'completed': categories.completed.map((e) => e.toJson()).toList(),
        'uncompleted': categories.uncompleted.map((e) => e.toJson()).toList(),
      },
    };
  }
}
