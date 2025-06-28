import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/theme_provider.dart';

class SessionEndSummary extends StatefulWidget {
  const SessionEndSummary({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<SessionEndSummary> createState() => _SessionEndSummaryState();
}

class _SessionEndSummaryState extends State<SessionEndSummary> {
  final bool _showTasksList = false;

  @override
  Widget build(BuildContext context) {
    final sessionModel = Provider.of<StudySessionModel>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final session = sessionModel.endedSession;
    if (session == null) {
      return Shimmer.fromColors(
        baseColor:
            themeProvider.isDarkMode ? Colors.grey[800]! : Colors.grey.shade300,
        highlightColor:
            themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey.shade100,
        child: Container(
          height: 200,
          width: double.infinity,
          color: themeProvider.isDarkMode
              ? Colors.grey[800]
              : Colors.grey.shade300,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildSessionHeader(session, themeProvider),
          const SizedBox(height: 16),
          _buildPercentIndicators(session, themeProvider),
          const SizedBox(height: 36),
          if (session.todos.isNotEmpty)
            _buildTaskSection(session, themeProvider),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onClose();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: themeProvider.primaryAppColor,
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

  Widget _buildSessionHeader(
      StudySession session, ThemeProvider themeProvider) {
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
            color: themeProvider.mainTextColor,
          ),
        ),
        const SizedBox(height: 18),
        _buildTimeStats(start: start, end: end, themeProvider: themeProvider),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDurationCard('Focus Time', formatDuration(actualStudy),
                Colors.green, themeProvider),
            _buildDurationCard('Break Time', formatDuration(actualBreak),
                themeProvider.primaryAppColor, themeProvider),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeStats(
      {required DateTime start,
      required DateTime end,
      required ThemeProvider themeProvider}) {
    final timeFormat = TimeOfDay.fromDateTime;
    String startText = timeFormat(start).format(context);
    String endText = timeFormat(end).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeRow(Icons.play_circle_fill, 'Started', startText,
            Colors.green, themeProvider),
        const SizedBox(height: 8),
        _buildTimeRow(
            Icons.stop_circle, 'Ended', endText, Colors.red, themeProvider),
      ],
    );
  }

  Widget _buildTimeRow(IconData icon, String label, String value, Color color,
      ThemeProvider themeProvider) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeProvider.mainTextColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: themeProvider.mainTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPercentIndicators(
      StudySession session, ThemeProvider themeProvider) {
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
                  color: themeProvider.mainTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Focus',
                style: GoogleFonts.inter(
                    fontSize: 12, color: themeProvider.secondaryTextColor),
              ),
            ],
          ),
          progressColor: Colors.green,
          backgroundColor: themeProvider.dividerColor,
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
                  color: themeProvider.mainTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Break',
                style: GoogleFonts.inter(
                    fontSize: 12, color: themeProvider.secondaryTextColor),
              ),
            ],
          ),
          progressColor: themeProvider.primaryAppColor,
          backgroundColor: themeProvider.dividerColor,
          circularStrokeCap: CircularStrokeCap.round,
        ),
      ],
    );
  }

  Widget _buildTaskSection(StudySession session, ThemeProvider themeProvider) {
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
                color: themeProvider.mainTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: themeProvider.dividerColor,
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
                  color: themeProvider.secondaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationCard(
      String title, String duration, Color color, ThemeProvider themeProvider) {
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
