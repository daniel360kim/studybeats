import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/side_widget_tile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class DateTile extends SideWidgetTile {
  const DateTile({required super.settings, super.key});
  DateTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: const Uuid().v4(),
            type: SideWidgetType.date,
            size: {'width': 160, 'height': 160},
            data: {
              'theme': 'default',
              'timezone': 'UTC',
            },
          ),
        );

  @override
  State<DateTile> createState() => _DateTileState();

  @override
  Map<String, dynamic> get defaultSettings => {
        'theme': 'default',
        'timezone': 'UTC',
      };
}

class _DateTileState extends State<DateTile> {
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
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      );
    }

    final theme = data['theme'];
    final now = DateTime.now();
    final weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][now.month - 1];

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color:
            theme == 'dark' ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              text: weekday,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
              children: [
                TextSpan(
                  text: ' $month',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme == 'dark' ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              '${now.day}',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: theme == 'dark' ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
