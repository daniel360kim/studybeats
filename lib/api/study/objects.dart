import 'package:json_annotation/json_annotation.dart';

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
  List<String> todoIds;
  int? sessionRating;
  int? soundFxId;
  bool soundEnabled;
  bool isLoopSession;
  
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
    required this.todoIds,
    this.sessionRating,
    this.soundFxId,
    required this.soundEnabled,
    required this.isLoopSession,
    required this.actualStudyDuration,
    required this.actualBreakDuration,
  });



  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startTime': startTime.toIso8601String(),
        'updatedTime': updatedTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'studyDuration': studyDuration.inMinutes,
        'breakDuration': breakDuration.inMinutes,
        'todoIds': todoIds,
        'sessionRating': sessionRating,
        'soundFxId': soundFxId,
        'soundEnabled': soundEnabled,
        'isLoopSession': isLoopSession,
        // Store actual durations as seconds so we capture full precision.
        'actualStudyDuration': actualStudyDuration.inSeconds,
        'actualBreakDuration': actualBreakDuration.inSeconds,
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
    List<String>? todoIds,
    int? sessionRating,
    int? soundFxId,
    bool? soundEnabled,
    bool? isLoopSession,
    Duration? actualStudyDuration,
    Duration? actualBreakDuration,
  }) {
    return StudySession(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      updatedTime: updatedTime ?? this.updatedTime,
      endTime: endTime ?? this.endTime,
      studyDuration: studyDuration ?? this.studyDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      todoIds: todoIds ?? this.todoIds,
      sessionRating: sessionRating ?? this.sessionRating,
      soundFxId: soundFxId ?? this.soundFxId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      isLoopSession: isLoopSession ?? this.isLoopSession,
      actualStudyDuration: actualStudyDuration ?? this.actualStudyDuration,
      actualBreakDuration: actualBreakDuration ?? this.actualBreakDuration,
    );
  }
}