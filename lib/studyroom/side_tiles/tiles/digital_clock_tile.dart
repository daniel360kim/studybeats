import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';

class DigitalClockTile extends SideWidgetTile {
  const DigitalClockTile({required super.settings, super.key});
  DigitalClockTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            type: SideWidgetType.digitalClock,
            title: 'Digital Clock',
            description: 'Displays the current time digitally',
            size: {'width': 1, 'height': 1},
            widgetId: const Uuid().v4(),
            data: {
              'theme': 'default',
              'timezone': 'UTC',
            },
          ),
        );

  @override
  State<DigitalClockTile> createState() => _DigitalClockTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: const Uuid().v4(),
      title: 'Digital Clock',
      description: 'Displays the current time digitally',
      type: SideWidgetType.digitalClock,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
        'timezone': 'UTC',
      },
    );
  }
}

class _DigitalClockTileState extends State<DigitalClockTile> {
  bool doneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    initSettings();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      );
    }

    if (error) {
      return showErrorContainer();
    }

    final theme = data['theme'];
    final timeString = "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}";

    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight,
      decoration: BoxDecoration(
        color: theme == 'dark' ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme == 'dark' ? Colors.white24 : Colors.grey.shade400,
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        timeString,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: theme == 'dark' ? Colors.white : Colors.black,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
