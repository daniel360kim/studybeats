import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:one_clock/one_clock.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/side_widget_tile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class ClockTile extends SideWidgetTile {
  const ClockTile({required super.settings, super.key});
  ClockTile.withDefaults({super.key})
      : super(
            settings: SideWidgetSettings(
          type: SideWidgetType.clock,
          size: {
            'width': 1,
            'height': 1,
          },
          // Generate a unique widget ID
          widgetId: Uuid().v4(),

          data: {
            'theme': 'default',
            'timezone': 'UTC',
          },
        ));

  @override
  State<ClockTile> createState() => _ClockTileState();

  @override
  Map<String, dynamic> get defaultSettings => {
        'theme': 'default',
        'timezone': 'UTC',
      };
}

class _ClockTileState extends State<ClockTile> {
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
          width: 100,
          height: 20,
          color: Colors.grey,
        ),
      );
    }

    final theme = data['theme'];
    //final timezone = data['timezone'];

    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnalogClock(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        width: 140.0,
        isLive: true,
        hourHandColor: theme == 'dark' ? Colors.white : Colors.black,
        minuteHandColor: theme == 'dark' ? Colors.white70 : Colors.black87,
        secondHandColor: Colors.redAccent,
        numberColor: theme == 'dark' ? Colors.white60 : Colors.black54,
        showSecondHand: true,
        showNumbers: true,
        showAllNumbers: true,
        textScaleFactor: 1.5,
        showTicks: true,
        tickColor: theme == 'dark' ? Colors.white24 : Colors.black26,
        showDigitalClock: false,
        datetime: DateTime.now(),
      ),
    );
  }
}
