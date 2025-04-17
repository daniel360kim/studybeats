import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/colors.dart';

class SessionEndSummary extends StatefulWidget {
  const SessionEndSummary({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<SessionEndSummary> createState() => _SessionEndSummaryState();
}

class _SessionEndSummaryState extends State<SessionEndSummary> {
  bool _showTasksList = false;

  @override
  Widget build(BuildContext context) {
    final sessionModel = Provider.of<StudySessionModel>(context);
    final session = sessionModel.endedSession;
    if (session == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 200,
          width: double.infinity,
          color: Colors.white,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildSessionHeader(session),
          const SizedBox(height: 16),
          _buildPercentIndicators(session),
          const SizedBox(height: 36),
          if (session.todos.isNotEmpty) _buildTaskSection(session),
          const SizedBox(height: 16),
          // Button to close this page
          ElevatedButton(
            onPressed: () {
              widget.onClose();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: kFlourishAdobe,
              foregroundColor: Colors.white,
              maximumSize: const Size(100, 50),
              minimumSize: const Size(100, 50),
            ),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the session header with title and start/end time and durations.
  Widget _buildSessionHeader(StudySession session) {
    final actualStudy = session.actualStudyDuration;
    final actualBreak = session.actualBreakDuration;
    final start = session.startTime;
    final end = session.endTime ?? DateTime.now();

    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
      if (minutes > 0) return '${minutes}m ${seconds}s';
      return '${seconds}s';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Summary',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 18),
        _buildTimeStats(start: start, end: end),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDurationCard(
                'Focus Time', formatDuration(actualStudy), Colors.green),
            _buildDurationCard(
                'Break Time', formatDuration(actualBreak), Colors.blue),
          ],
        ),
      ],
    );
  }

  /// Build a row for start and end times with icons.
  Widget _buildTimeStats({required DateTime start, required DateTime end}) {
    final timeFormat = TimeOfDay.fromDateTime;
    String startText = timeFormat(start).format(context);
    String endText = timeFormat(end).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeRow(
            Icons.play_circle_fill, 'Started', startText, Colors.green),
        const SizedBox(height: 8),
        _buildTimeRow(Icons.stop_circle, 'Ended', endText, Colors.red),
      ],
    );
  }

  Widget _buildTimeRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// Build the row with circular indicators for study and break percentages.
  Widget _buildPercentIndicators(StudySession session) {
    final actualStudy = session.actualStudyDuration;
    final actualBreak = session.actualBreakDuration;
    final totalSeconds = actualStudy.inSeconds + actualBreak.inSeconds;
    double studyPercentage =
        totalSeconds > 0 ? actualStudy.inSeconds / totalSeconds : 0.0;
    double breakPercentage =
        totalSeconds > 0 ? actualBreak.inSeconds / totalSeconds : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircularPercentIndicator(
          radius: 60.0,
          lineWidth: 12.0,
          percent: studyPercentage,
          animation: true,
          animationDuration: 1000,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(studyPercentage * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Focus',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ],
          ),
          progressColor: Colors.green,
          backgroundColor: Colors.grey.shade300,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        CircularPercentIndicator(
          radius: 60.0,
          lineWidth: 12.0,
          percent: breakPercentage,
          animation: true,
          animationDuration: 1000,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(breakPercentage * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Break',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ],
          ),
          progressColor: Colors.blue,
          backgroundColor: Colors.grey.shade300,
          circularStrokeCap: CircularStrokeCap.round,
        ),
      ],
    );
  }

  /// Builds the task section – either a task completion summary if tasks exist,
  /// or a shimmer effect placeholder if tasks are loading or empty.
  Widget _buildTaskSection(StudySession session) {
    final todoItems = session.todos;
    final completed = session.numCompletedTasks;
    final total = todoItems.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'You completed $completed task${completed == 1 ? '' : 's'}!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            color: Colors.green,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$completed of $total tasks completed',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a card that displays a duration label and its value.
  Widget _buildDurationCard(String title, String duration, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            duration,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
