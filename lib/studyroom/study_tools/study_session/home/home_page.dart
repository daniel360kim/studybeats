import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/theme_provider.dart';

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
    final initialization = _studySessionService.init();
    _currentStreakFuture =
        initialization.then((_) => _studySessionService.getCurrentStreak());
    _allTimeStatsFuture =
        initialization.then((_) => _studySessionService.getAllTimeStatistics());
    _initAuth();
  }

  void _initAuth() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _isAnonymous = user.isAnonymous;
      });
    }
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildStartSessionButton(themeProvider),
          if (_isAnonymous && !_dismissedAnonWarning)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: themeProvider.warningBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeProvider.warningBorderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: themeProvider.warningIconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Sessions won't be saved unless you're logged in.",
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.warningTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: themeProvider.warningTextColor),
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
          _buildStreakCard(themeProvider),
          const SizedBox(height: 20),
          _buildAllTimeStats(themeProvider),
          const SizedBox(height: 20),
          _buildWeeklyChartSection(themeProvider),
        ],
      ),
    );
  }

  Widget _buildAllTimeStats(ThemeProvider themeProvider) {
    return FutureBuilder<StudyStatistics>(
      future: _allTimeStatsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: themeProvider.isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[100]!,
            highlightColor: themeProvider.isDarkMode
                ? Colors.grey[700]!
                : Colors.grey[200]!,
            child: Container(
              width: 450,
              height: 200,
              decoration: BoxDecoration(
                color: themeProvider.appContentBackgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text('No data',
              style: TextStyle(color: themeProvider.mainTextColor));
        }

        final totalStudy = snapshot.data!.totalStudyTime;
        final totalBreak = snapshot.data!.totalBreakTime;
        final totalTodosCompleted =
            snapshot.data!.totalTodosCompleted.toString();

        return Container(
          width: 450,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.appContentBackgroundColor,
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
                  color: themeProvider.mainTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMetricCard(
                    'Focus Time',
                    _formatTime(totalStudy),
                    kFlourishAdobe,
                    themeProvider,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Break Time',
                    _formatTime(totalBreak),
                    Colors.blueAccent,
                    themeProvider,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Todos Completed',
                    totalTodosCompleted,
                    Colors.greenAccent,
                    themeProvider,
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

  Widget _buildMetricCard(
      String label, String value, Color color, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: themeProvider.mainTextColor)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeProvider.mainTextColor),
        ),
      ],
    );
  }

  Widget _buildWeekNavigator(ThemeProvider themeProvider) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: themeProvider.iconColor),
          onPressed: () => setState(() => _weeksBack++),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Week of ${_formatDate(_getStartOfWeek(_weeksBack))}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.mainTextColor,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: themeProvider.iconColor),
          onPressed: _weeksBack > 0 ? () => setState(() => _weeksBack--) : null,
        ),
      ],
    );
  }

  Widget _buildWeeklyChartSection(ThemeProvider themeProvider) {
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
              color: themeProvider.appContentBackgroundColor,
            ),
          );
        }
        if (snapshot.hasError) {
          return Text('Error loading weekly data: ${snapshot.error}',
              style: TextStyle(color: themeProvider.mainTextColor));
        }
        final statsMap = snapshot.data!;
        final start = _getStartOfWeek(_weeksBack);

        final rawMaxMinutes = statsMap.values
            .map((s) => s.totalStudyTime.inMinutes + s.totalBreakTime.inMinutes)
            .fold(0, (prev, e) => prev > e ? prev : e);

        double chartMaxY;
        double interval;
        bool useMinuteLabels = false;
        if (rawMaxMinutes > 0 && rawMaxMinutes < 60) {
          chartMaxY = 1.0;
          interval = 0.25;
          useMinuteLabels = true;
        } else {
          final rawMaxHours = rawMaxMinutes / 60.0;
          const int segments = 4;
          final rawInterval = rawMaxHours / segments;
          interval = rawInterval > 1 ? rawInterval.ceilToDouble() : 1.0;
          chartMaxY = interval * segments;
        }

        final totalStudySeconds = statsMap.values
            .map((s) => s.totalStudyTime.inSeconds)
            .fold(0, (prev, e) => prev + e);

        final totalBreakSeconds = statsMap.values
            .map((s) => s.totalBreakTime.inSeconds)
            .fold(0, (prev, e) => prev + e);

        final dailyAverageStudy = Duration(seconds: totalStudySeconds ~/ 7);

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
          final studyColor = isFuture ? Colors.grey.shade700 : kFlourishAdobe;
          final breakColor =
              isFuture ? Colors.grey.shade800 : Colors.blueAccent;

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
            color: themeProvider.appContentBackgroundColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekNavigator(themeProvider),
              const SizedBox(height: 16),
              Text(
                'Daily Average',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: themeProvider.secondaryTextColor,
                ),
              ),
              Text(
                _formatTime(dailyAverageStudy),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.mainTextColor,
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
                        color: themeProvider.dividerColor,
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
                              style: TextStyle(
                                  fontSize: 12,
                                  color: themeProvider.mainTextColor),
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
                            final style = TextStyle(
                                fontSize: 10,
                                color: themeProvider.secondaryTextColor);
                            if (useMinuteLabels) {
                              final mins = (value * 60).toInt();
                              return Text('${mins}m', style: style);
                            } else {
                              return Text('${value.toInt()}h', style: style);
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
                  buildLegendItem('Focus', kFlourishAdobe,
                      Duration(seconds: totalStudySeconds), themeProvider),
                  const SizedBox(width: 20),
                  buildLegendItem('Break', Colors.blueAccent,
                      Duration(seconds: totalBreakSeconds), themeProvider),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget buildLegendItem(
      String label, Color color, Duration time, ThemeProvider themeProvider) {
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
            color: themeProvider.mainTextColor,
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

  Widget _buildStreakCard(ThemeProvider themeProvider) {
    return FutureBuilder<int>(
      future: _currentStreakFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('No data',
              style: TextStyle(color: themeProvider.mainTextColor));
        }
        final streak = snap.data!;
        return Container(
          width: 450,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.appContentBackgroundColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeProvider.primaryAppColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department,
                  color: themeProvider.primaryAppColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Streak',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.mainTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$streak day${streak == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.primaryAppColor),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartSessionButton(ThemeProvider provider) {
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
          backgroundColor: provider.primaryAppColor,
          foregroundColor: provider.emphasisColor,
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
