import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/colors.dart';

class StudySessionHomePage extends StatefulWidget {
  const StudySessionHomePage({required this.onSessionStart, super.key});

  final VoidCallback onSessionStart;

  @override
  State<StudySessionHomePage> createState() => _StudySessionHomePageState();
}

class _StudySessionHomePageState extends State<StudySessionHomePage> {
  final StudySessionService _studySessionService = StudySessionService();
  late Future<int> _currentStreakFuture;
  late Future<StudyStatistics> _allTimeStatsFuture;
  int _weeksBack = 0;
  bool _isAnonymous = false;
  bool _dismissedAnonWarning = false;

  @override
  void initState() {
    super.initState();
    // Initialize service once, then fetch streak and stats
    final initialization = _studySessionService.init();
    _currentStreakFuture =
        initialization.then((_) => _studySessionService.getCurrentStreak());
    _allTimeStatsFuture =
        initialization.then((_) => _studySessionService.getAllTimeStatistics());
    _initAuth();
  }

  void _initAuth() async {
    // Import AuthService at the top of your file if not already imported.
    // ignore: import_of_legacy_library_into_null_safe

    final user = await AuthService().getCurrentUser();
    setState(() {
      _isAnonymous = user.isAnonymous;
    });
  }

  DateTime _getStartOfWeek(int weeksBack) {
    final now = DateTime.now();
    final reference = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weeksBack * 7));
    final daysToSubtract = reference.weekday % 7;
    return reference.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildStartSessionButton(),
          if (_isAnonymous && !_dismissedAnonWarning)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 20, color: Color(0xFFF57C00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Sessions won't be saved unless you're logged in.",
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6D4C41),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Color(0xFF6D4C41)),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _dismissedAnonWarning = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _buildStreakCard(),
          const SizedBox(height: 20),
          _buildAllTimeStats(),
          const SizedBox(height: 20),
          _buildWeeklyChartSection(),
        ],
      ),
    );
  }

  Widget _buildAllTimeStats() {
    return FutureBuilder<StudyStatistics>(
      future: _allTimeStatsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: kFlourishAliceBlue,
            highlightColor: Colors.grey.shade200,
            child: Container(
              width: 450,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text('No data');
        }

        final totalStudy = snapshot.data!.totalStudyTime;
        final totalBreak = snapshot.data!.totalBreakTime;
        final totalTodosCompleted =
            snapshot.data!.totalTodosCompleted.toString();

        return Container(
          width: 450,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Time Statistics',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMetricCard(
                    'Focus Time',
                    _formatTime(totalStudy),
                    kFlourishBlue,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Break Time',
                    _formatTime(totalBreak),
                    kFlourishAdobe,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Todos Completed',
                    totalTodosCompleted,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildWeekNavigator() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _weeksBack++),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Week of ${_formatDate(_getStartOfWeek(_weeksBack))}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _weeksBack > 0 ? () => setState(() => _weeksBack--) : null,
        ),
      ],
    );
  }

  Widget _buildWeeklyChartSection() {
    return FutureBuilder<Map<DateTime, StudyStatistics>>(
      future:
          _studySessionService.getWeeklyDailyStatistics(weeksBack: _weeksBack),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 380,
            width: 450,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
            ),
          );
        }
        if (snapshot.hasError) {
          return Text('Error loading weekly data: ${snapshot.error}');
        }
        final statsMap = snapshot.data!;
        final start = _getStartOfWeek(_weeksBack);

        // Determine raw maximum minutes across study and break
        final rawMaxMinutes = statsMap.values
            .map((s) => s.totalStudyTime.inMinutes + s.totalBreakTime.inMinutes)
            .reduce((a, b) => a > b ? a : b);
        // If maximum is under 60 minutes, use four 15-minute intervals
        double chartMaxY;
        double interval;
        bool useMinuteLabels = false;
        if (rawMaxMinutes > 0 && rawMaxMinutes < 60) {
          // 1 hour = 4 intervals of 15 minutes -> 1.0 hours total
          chartMaxY = 1.0;
          interval = 0.25; // quarter hour
          useMinuteLabels = true;
        } else {
          // Convert to hours and split into 4 segments
          final rawMaxHours = rawMaxMinutes / 60.0;
          const int segments = 4;
          final rawInterval = rawMaxHours / segments;
          interval = rawInterval > 1 ? rawInterval.ceilToDouble() : 1.0;
          chartMaxY = interval * segments;
        }

        // Calculate daily averages for the week
        final totalStudySeconds = statsMap.values
            .map((s) => s.totalStudyTime.inSeconds)
            .fold(0, (prev, e) => prev + e);

        final totalBreakSeconds = statsMap.values
            .map((s) => s.totalBreakTime.inSeconds)
            .fold(0, (prev, e) => prev + e);

        final dailyAverageStudy = Duration(seconds: totalStudySeconds ~/ 7);

        // Build grouped bars
        final bars = <BarChartGroupData>[];
        for (int i = 0; i < 7; i++) {
          final day = start.add(Duration(days: i));
          final stats = statsMap[DateTime(day.year, day.month, day.day)]!;
          final studyVal = stats.totalStudyTime.inMinutes.toDouble() / 60.0;
          final breakVal = stats.totalBreakTime.inMinutes.toDouble() / 60.0;
          final totalVal = studyVal + breakVal;

          final today = DateTime.now();
          final isFuture = DateTime(day.year, day.month, day.day).isAfter(
            DateTime(today.year, today.month, today.day),
          );
          final studyColor = isFuture ? Colors.grey.shade300 : kFlourishBlue;
          final breakColor = isFuture ? Colors.grey.shade200 : kFlourishAdobe;

          bars.add(BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: totalVal,
                width: 20,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [
                  BarChartRodStackItem(0, studyVal, studyColor),
                  BarChartRodStackItem(studyVal, totalVal, breakColor),
                ],
              ),
            ],
          ));
        }

        return Container(
          height: 380,
          width: 450,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekNavigator(),
              const SizedBox(height: 16),
              Text(
                'Daily Average',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kFlourishLightBlackish,
                ),
              ),
              Text(
                _formatTime(dailyAverageStudy),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: chartMaxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = start.add(Duration(days: group.x));
                          final studyTime =
                              statsMap[date]!.totalStudyTime.inMinutes;
                          final breakTime =
                              statsMap[date]!.totalBreakTime.inMinutes;
                          return BarTooltipItem(
                            '${_formatDate(date)}\n'
                            'Focus: ${_formatTime(Duration(minutes: studyTime))}\n'
                            'Break: ${_formatTime(Duration(minutes: breakTime))}',
                            textAlign: TextAlign.center,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (x, meta) {
                            final labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                            return Text(
                              labels[x.toInt()],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: interval,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (useMinuteLabels) {
                              final mins = (value * 60).toInt();
                              return Text('${mins}m',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black54));
                            } else {
                              return Text('${value.toInt()}h',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black54));
                            }
                          },
                        ),
                      ),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: bars,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  buildLegendItem('Focus', kFlourishBlue,
                      Duration(seconds: totalStudySeconds)),
                  const SizedBox(width: 20),
                  buildLegendItem('Break', kFlourishAdobe,
                      Duration(seconds: totalBreakSeconds)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget buildLegendItem(String label, Color color, Duration time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatTime(time),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
  String _formatTime(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else {
      return '${d.inMinutes}m';
    }
  }

  Widget _buildStreakCard() {
    return FutureBuilder<int>(
      future: _currentStreakFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('No data');
        }
        final streak = snap.data!;
        return Container(
          width: 450,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              // Icon and vertical separator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kFlourishAdobe.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department,
                  color: kFlourishAdobe,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Streak',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$streak day${streak == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kFlourishAdobe),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders a prominent “Start Session” button fitting the app aesthetic.
  Widget _buildStartSessionButton() {
    return SizedBox(
      width: 100,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow, size: 20),
        label: Text(
          'Start New Session',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          maximumSize: const Size(100, 50),
          minimumSize: const Size(100, 50),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: kFlourishAdobe,
          foregroundColor: kFlourishAliceBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: widget.onSessionStart,
      ),
    );
  }
}
