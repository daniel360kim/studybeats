import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:uuid/uuid.dart';

class StudyStatisticsTile extends SideWidgetTile {
  const StudyStatisticsTile({required super.settings, super.key});

  StudyStatisticsTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: Uuid().v4(),
            title: 'Study Statistics',
            description: 'Displays your study statistics',
            type: SideWidgetType.studyStatistics,
            size: {'width': 1, 'height': 1},
            data: {
              'theme': 'default',
            },
          ),
        );

  @override
  State<StudyStatisticsTile> createState() => _StudyStatisticsTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Study Statistics',
      description: 'Displays your study statistics',
      type: SideWidgetType.studyStatistics,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
        'timezone': 'UTC',
      },
    );
  }
}

class _StudyStatisticsTileState extends State<StudyStatisticsTile> {
  bool doneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};

  final _studySessionService = StudySessionService();

  StudyStatistics? _studyStatistics;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    try {
      await _studySessionService.init();
      data = await widget.loadSettings(SideWidgetService());
      _studyStatistics = await _studySessionService.getAllTimeStatistics();
      if (_studyStatistics == null) {
        setState(() {
          error = true;
        });
      }
      setState(() {
        doneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!doneLoading || _studyStatistics == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          // Use the tile unit dimensions for consistency
          width: kTileUnitWidth,
          height: kTileUnitHeight,

          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12.0), // Match widget radius
          ),
        ),
      );
    }

    if (error) {
      return showErrorContainer();
    }

    return GestureDetector(
      onTap: () {
        // Open the todo list in the toolbar
        Provider.of<StudyToolbarController>(context, listen: false)
            .openOption(NavigationOption.timer);

        // Close the side panel if it's open
        Provider.of<SidePanelController>(context, listen: false).close();
      },
      child: Container(
          width: kTileUnitWidth,
          height: kTileUnitHeight,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: kFlourishAliceBlue,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricCard(
                'Focus Time',
                _formatTime(_studyStatistics!.totalStudyTime),
                kFlourishAdobe,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                'Break Time',
                _formatTime(_studyStatistics!.totalBreakTime),
                Colors.blueAccent,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                'Todos Completed',
                _studyStatistics!.totalTodosCompleted.toString(),
                Colors.green,
              )
            ],
          )),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 3, backgroundColor: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTime(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else {
      return '${d.inMinutes}m';
    }
  }
}
