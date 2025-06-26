import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:uuid/uuid.dart';

/// A side‑panel widget that shows a single animated line graph of the
/// user’s focus time for the current week.  Tapping it navigates to
/// the full Study Timer view.
class StudyGraphsTile extends SideWidgetTile {
  const StudyGraphsTile({required super.settings, super.key});

  /// Convenience constructor with sane defaults so the tile can be
  /// dropped into any grid without manual settings wiring.
  StudyGraphsTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: const Uuid().v4(),
            title: 'Study Graph',
            description: 'Weekly focus‑time graph',
            // Use existing type until a dedicated enum value is added.
            type: SideWidgetType.studyGraph,
            size: {'width': 1, 'height': 1},
            data: const {},
          ),
        );

  @override
  State<StudyGraphsTile> createState() => _StudyGraphsTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: const Uuid().v4(),
      title: 'Study Graph',
      description: 'Weekly focus‑time graph',
      type: SideWidgetType.studyGraph,
      size: {'width': 1, 'height': 1},
      data: const {},
    );
  }
}

class _StudyGraphsTileState extends State<StudyGraphsTile>
    with SingleTickerProviderStateMixin {
  final StudySessionService _studySessionService = StudySessionService();

  bool _loading = true;
  bool _error = false;

  double _studyMinutes = 0;
  double _breakMinutes = 0;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc);
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _studySessionService.init();
      final weeklyStats =
          await _studySessionService.getWeeklyDailyStatistics(weeksBack: 0);

      if (weeklyStats.isEmpty) {
        _error = true;
      } else {
        _studyMinutes = weeklyStats.values
            .map((d) => d.totalStudyTime.inMinutes.toDouble())
            .fold(0, (a, b) => a + b);

        // If your StudyStatistics model has a breakTime field, use that.
        // Otherwise, assume 5‑min break per 25‑min study as an estimate.
        _breakMinutes = weeklyStats.values
            .map((d) =>
                d.totalBreakTime?.inMinutes.toDouble() ??
                (d.totalStudyTime.inMinutes / 5))
            .fold(0, (a, b) => a + b);
      }
    } catch (_) {
      _error = true;
    }

    if (mounted) {
      setState(() => _loading = false);
      if (!_error) _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: kTileUnitWidth,
          height: kTileUnitHeight,
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (_error) {
      return showErrorContainer();
    }

    return GestureDetector(
      onTap: () {
        context
            .read<StudyToolbarController>()
            .openOption(NavigationOption.timer);
        context.read<SidePanelController>().close();
      },
      child: Container(
        width: kTileUnitWidth,
        height: kTileUnitHeight,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kFlourishBlackish,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return _buildDonut(_animation.value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonut(double progress) {
    final total = _studyMinutes + _breakMinutes;

    // helper widgets ----------------------------------------------------------
    Widget legendDot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
          ],
        );

    Widget ring(List<PieChartSectionData> sections, double size) => SizedBox(
          width: size,
          height: size,
          child: PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: size * .34, // keeps the hole proportional
              sections: sections,
            ),
          ),
        );

    // -------------------------------------------------------------------------
    return LayoutBuilder(
      builder: (context, constraints) {
        // leave 22 px for legend so the ring never overflows

        // empty state ----------------------------------------------------------
        if (total == 0) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ring(
                    [
                      PieChartSectionData(
                        value: 1,
                        color: Colors.grey.shade700,
                        showTitle: false,
                        radius: 12,
                      )
                    ],
                    constraints.maxWidth - 22, // leave space for legend
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('0',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('min',
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          );
        }

        // data state ----------------------------------------------------------
        final studyVal = (_studyMinutes / total) * progress;
        final breakVal = (_breakMinutes / total) * progress;
        final studyHrs = (_studyMinutes / 60).toStringAsFixed(1);

        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ring(
                  [
                    PieChartSectionData(
                      value: studyVal,
                      color: kFlourishBlue,
                      showTitle: false,
                      radius: 12,
                    ),
                    PieChartSectionData(
                      value: breakVal,
                      color: kFlourishAdobe,
                      showTitle: false,
                      radius: 12,
                    ),
                  ],
                  constraints.maxWidth - 22, // leave space for legend
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(studyHrs,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('hrs study',
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
