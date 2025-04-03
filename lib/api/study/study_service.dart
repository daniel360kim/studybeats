import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/study/objects.dart';

import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';

class StudySessionService {
  final _authService = AuthService();
  final _logger = getLogger('Study Session Service');

  late final CollectionReference<Map<String, dynamic>> _studySessionCollection;
  late final CollectionReference<Map<String, dynamic>>
      _studyStatisticsCollection;

  Future<void> init() async {
    try {
      final email = await _getUserEmail();
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _studySessionCollection = userDoc.collection('studySessions');
      _studyStatisticsCollection = userDoc.collection('studyStatistics');
    } catch (e, s) {
      _logger.e('Failed to initialize study session service: $e $s');
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

  Future<void> createSession(StudySession session) async {
    try {
      _logger.i('Creating study session');
      await _studySessionCollection.doc(session.id).set(session.toJson());
    } catch (e, s) {
      _logger.e('Failed to create study session: $e $s');
      rethrow;
    }
  }

  Future<void> updateSession(StudySession session) async {
    try {
      _logger.i('Updating study session');
      await _studySessionCollection.doc(session.id).update(session.toJson());
    } catch (e, s) {
      _logger.e('Failed to update study session: $e $s');
      rethrow;
    }
  }

  Future<void> endSession(StudySession session) async {
    try {
      _logger.i('Ending study session');
      if (session.endTime == null) {
        session = StudySession(
          id: session.id,
          title: session.title,
          startTime: session.startTime,
          updatedTime: session.updatedTime,
          endTime: session.updatedTime,
          studyDuration: session.studyDuration,
          breakDuration: session.breakDuration,
          todoIds: session.todoIds,
          sessionRating: session.sessionRating,
        );
      }
      await updateSession(session);
      await _updateTotalStatistics(session);
    } catch (e, s) {
      _logger.e('Failed to end study session: $e $s');
      rethrow;
    }
  }

  Future<void> _updateTotalStatistics(StudySession session) async {
    final statsDocRef = _studyStatisticsCollection.doc('totalStats');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final statsSnapshot = await transaction.get(statsDocRef);
      if (!statsSnapshot.exists) {
        final newStats = StudyStatistics(
          totalStudyTime: session.studyDuration.inMinutes,
          totalBreakTime: session.breakDuration.inMinutes,
          totalSessions: 1,
          totalTodosCompleted: session.todoIds.length,
        );
        transaction.set(statsDocRef, newStats.toJson());
      } else {
        final currentData = statsSnapshot.data()!;
        final currentStats = StudyStatistics.fromJson(currentData);
        final updatedStats = StudyStatistics(
          totalStudyTime:
              currentStats.totalStudyTime + session.studyDuration.inMinutes,
          totalBreakTime:
              currentStats.totalBreakTime + session.breakDuration.inMinutes,
          totalSessions: currentStats.totalSessions + 1,
          totalTodosCompleted:
              currentStats.totalTodosCompleted + session.todoIds.length,
        );
        transaction.update(statsDocRef, updatedStats.toJson());
      }
    });
  }

  /// Client-side aggregation methods for daily, weekly, and monthly stats.
  /// These methods query the sessions collection by date range and aggregate the totals.

  Future<StudyStatistics> getDailyStatistics(DateTime date) async {
    // Set up boundaries for "today"
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    return _getAggregatedStatistics(startOfDay, endOfDay);
  }

  Future<StudyStatistics> getWeeklyStatistics(DateTime date) async {
    // Get statistics from week before the given date
    DateTime startOfWeek = date.subtract(Duration(days: date.weekday));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 7));

    return _getAggregatedStatistics(startOfWeek, endOfWeek);
  }

  Future<StudyStatistics> getMonthlyStatistics(DateTime date) async {
    // Get statistics from month before the given date
    DateTime startOfMonth = DateTime(date.year, date.month);
    DateTime endOfMonth = DateTime(date.year, date.month + 1);

    return _getAggregatedStatistics(startOfMonth, endOfMonth);
  }

  Future<StudyStatistics> _getAggregatedStatistics(
      DateTime start, DateTime end) async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _studySessionCollection
        .where('startTime', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('startTime', isLessThan: end.toIso8601String())
        .get();

    int totalStudyTime = 0;
    int totalBreakTime = 0;
    int totalSessions = snapshot.docs.length;
    int totalTodosCompleted = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalStudyTime += data['studyDuration'] as int;
      totalBreakTime += data['breakDuration'] as int;
      totalTodosCompleted += (data['todoIds'] as List).length;
    }

    return StudyStatistics(
      totalStudyTime: totalStudyTime,
      totalBreakTime: totalBreakTime,
      totalSessions: totalSessions,
      totalTodosCompleted: totalTodosCompleted,
    );
  }
}
