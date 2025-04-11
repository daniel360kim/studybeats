import 'package:json_annotation/json_annotation.dart';

class StudyStatistics {
  final int totalStudyTime;
  final int totalBreakTime;
  final int totalSessions;
  final int totalTodosCompleted;

  StudyStatistics({
    required this.totalStudyTime,
    required this.totalBreakTime,
    required this.totalSessions,
    required this.totalTodosCompleted,
  });

  factory StudyStatistics.fromJson(Map<String, dynamic> json) =>
      StudyStatistics(
        totalStudyTime: json['totalStudyTime'] as int,
        totalBreakTime: json['totalBreakTime'] as int,
        totalSessions: json['totalSessions'] as int,
        totalTodosCompleted: json['totalTodosCompleted'] as int,
      );

  Map<String, dynamic> toJson() => {
        'totalStudyTime': totalStudyTime,
        'totalBreakTime': totalBreakTime,
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

  Duration actualStudyDuration;
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

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        title: json['title'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        updatedTime: DateTime.parse(json['updatedTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        studyDuration: Duration(minutes: json['studyDuration'] as int),
        breakDuration: Duration(minutes: json['breakDuration'] as int),
        todoIds: List<String>.from(json['todoIds'] as List),
        sessionRating: json['sessionRating'] as int?,
        soundFxId: json['soundFxId'] as int?,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        isLoopSession: json['isLoopSession'] as bool? ?? true,
        actualStudyDuration: json.containsKey('actualStudyDuration')
            ? Duration(minutes: json['actualStudyDuration'] as int)
            : Duration.zero,
        actualBreakDuration: json.containsKey('actualBreakDuration')
            ? Duration(minutes: json['actualBreakDuration'] as int)
            : Duration.zero,
      );

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
        'actualStudyDuration': actualStudyDuration.inMinutes,
        'actualBreakDuration': actualBreakDuration.inMinutes,
      };
}