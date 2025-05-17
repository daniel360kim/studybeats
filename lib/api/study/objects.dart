import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

class SessionTodoReference {
  final String todoId;
  final String todoListId;

  SessionTodoReference({required this.todoId, required this.todoListId});

  factory SessionTodoReference.fromJson(Map<String, dynamic> json) =>
      SessionTodoReference(
        todoId: json['todoId'] as String,
        todoListId: json['todoListId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'todoId': todoId,
        'todoListId': todoListId,
      };
}

class StudyStatistics {
  /// Total study time as a Duration.
  final Duration totalStudyTime;

  /// Total break time as a Duration.
  final Duration totalBreakTime;

  /// Total number of sessions.
  final int totalSessions;

  /// Total number of todos completed.
  final int totalTodosCompleted;

  StudyStatistics({
    required this.totalStudyTime,
    required this.totalBreakTime,
    required this.totalSessions,
    required this.totalTodosCompleted,
  });

  /// Constructs an instance from JSON by reading durations stored in seconds.
  factory StudyStatistics.fromJson(Map<String, dynamic> json) =>
      StudyStatistics(
        totalStudyTime: Duration(seconds: json['totalStudyTime'] as int),
        totalBreakTime: Duration(seconds: json['totalBreakTime'] as int),
        totalSessions: json['totalSessions'] as int,
        totalTodosCompleted: json['totalTodosCompleted'] as int,
      );

  /// Converts this instance to JSON by writing durations in seconds.
  Map<String, dynamic> toJson() => {
        'totalStudyTime': totalStudyTime.inSeconds,
        'totalBreakTime': totalBreakTime.inSeconds,
        'totalSessions': totalSessions,
        'totalTodosCompleted': totalTodosCompleted,
      };
}

@JsonSerializable()
class StudySession {
  String id;
  String title;
  DateTime startTime;
  DateTime updatedTime;
  DateTime? endTime;
  Duration studyDuration; // Planned study duration
  Duration breakDuration; // Planned break duration
  Set<SessionTodoReference> todos;
  int? sessionRating;
  int? soundFxId;
  bool soundEnabled;
  Color themeColor;
  String? todoListId;
  int numCompletedTasks;

  /// Actual study duration accumulated during the session.
  Duration actualStudyDuration;

  /// Actual break duration accumulated during the session.
  Duration actualBreakDuration;

  StudySession({
    required this.id,
    required this.title,
    required this.startTime,
    required this.updatedTime,
    this.endTime,
    required this.studyDuration,
    required this.breakDuration,
    required this.todos,
    this.sessionRating,
    this.soundFxId,
    required this.soundEnabled,
    required this.actualStudyDuration,
    required this.actualBreakDuration,
    this.themeColor = Colors.blue,
    this.todoListId,
    this.numCompletedTasks = 0,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'],
        title: json['title'],
        startTime: DateTime.parse(json['startTime']),
        updatedTime: DateTime.parse(json['updatedTime']),
        endTime:
            json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        studyDuration: Duration(minutes: json['studyDuration']),
        breakDuration: Duration(minutes: json['breakDuration']),
        todos: (json['todos'] as List<dynamic>)
            .map(
                (e) => SessionTodoReference.fromJson(e as Map<String, dynamic>))
            .toSet(),
        sessionRating: json['sessionRating'],
        soundFxId: json['soundFxId'],
        soundEnabled: json['soundEnabled'],
        actualStudyDuration: Duration(seconds: json['actualStudyDuration']),
        actualBreakDuration: Duration(seconds: json['actualBreakDuration']),
        themeColor: Color(json['themeColor']),
        todoListId: json['todoListId'],
        numCompletedTasks: json['numCompletedTasks'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startTime': startTime.toIso8601String(),
        'updatedTime': updatedTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'studyDuration': studyDuration.inMinutes,
        'breakDuration': breakDuration.inMinutes,
        'todos': todos.map((t) => t.toJson()).toList(),
        'sessionRating': sessionRating,
        'soundFxId': soundFxId,
        'soundEnabled': soundEnabled,

        // Store actual durations as seconds so we capture full precision.
        'actualStudyDuration': actualStudyDuration.inSeconds,
        'actualBreakDuration': actualBreakDuration.inSeconds,
        'themeColor': themeColor.value,
        'todoListId': todoListId,
        'numCompletedTasks': numCompletedTasks,
      };

  /// Creates a copy of this StudySession with the given fields replaced by new values.
  StudySession copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? updatedTime,
    DateTime? endTime,
    Duration? studyDuration,
    Duration? breakDuration,
    List<SessionTodoReference>? todos,
    int? sessionRating,
    int? soundFxId,
    bool? soundEnabled,
    bool? isLoopSession,
    Duration? actualStudyDuration,
    Duration? actualBreakDuration,
    Color? themeColor,
    String? todoListId,
    int? numCompletedTasks,
  }) {
    return StudySession(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      updatedTime: updatedTime ?? this.updatedTime,
      endTime: endTime ?? this.endTime,
      studyDuration: studyDuration ?? this.studyDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      todos: todos != null ? Set<SessionTodoReference>.from(todos) : this.todos,
      sessionRating: sessionRating ?? this.sessionRating,
      soundFxId: soundFxId ?? this.soundFxId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      actualStudyDuration: actualStudyDuration ?? this.actualStudyDuration,
      actualBreakDuration: actualBreakDuration ?? this.actualBreakDuration,
      themeColor: themeColor ?? this.themeColor,
      todoListId: todoListId ?? this.todoListId,
      numCompletedTasks: numCompletedTasks ?? this.numCompletedTasks,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
