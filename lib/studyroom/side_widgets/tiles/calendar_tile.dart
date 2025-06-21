import 'package:flutter/material.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/side_widget_tile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class CalendarTile extends SideWidgetTile {
  const CalendarTile({required super.settings, super.key});
  CalendarTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: Uuid().v4(),
            title: 'Calendar',
            description: 'Displays the current date',
            type: SideWidgetType.calendar,
            size: {'width': 1, 'height': 1},
            data: {
              'theme': 'default',
              'timezone': 'UTC',
            },
          ),
        );

  @override
  State<CalendarTile> createState() => _CalendarTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Calendar',
      description: 'Displays the current date',
      type: SideWidgetType.calendar,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
        'timezone': 'UTC',
      },
    );
  }
}

class _CalendarTileState extends State<CalendarTile> {
  bool doneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    initSettings();
  }

  void initSettings() async {
    try {
      data = await widget.loadSettings(SideWidgetService());
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
    if (!doneLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
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

    final theme = data['theme'];
    // final timezone = data['timezone'];

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    final List<Widget> dayWidgets = [];

    for (var i = 1; i < startingWeekday; i++) {
      dayWidgets.add(Container()); // empty leading cells
    }

    for (var i = 1; i <= daysInMonth; i++) {
      final isToday = now.day == i;

      dayWidgets.add(
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? Colors.redAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Text(
            '$i',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? (theme == 'dark' ? Colors.black : Colors.white)
                  : (theme == 'dark' ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      );
    }

    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color:
            theme == 'dark' ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
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
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December'
              ][now.month - 1],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: dayWidgets,
          ),
        ],
      ),
    );
  }
}
