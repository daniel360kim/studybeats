import 'dart:math';
import 'package:flutter/material.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class ClockTile extends SideWidgetTile {
  const ClockTile({required super.settings, super.key});
  ClockTile.withDefaults({super.key})
      : super(
            settings: SideWidgetSettings(
          type: SideWidgetType.clock,
          title: 'Analog Clock',
          description: 'Displays the current time',
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
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Analog Clock',
      description: 'Displays the current time',
      type: SideWidgetType.clock,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
        'timezone': 'UTC',
      },
    );
  }
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
      // In a real app, you might have an async delay for loading
      // await Future.delayed(const Duration(seconds: 1));
      data = await widget.loadSettings(SideWidgetService());
      if (mounted) {
        setState(() {
          doneLoading = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = true;
        });
      }
    }
  }

  Widget showErrorContainer() {
    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red),
      ),
      child: const Center(
        child: Text(
          'Error loading widget',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
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
    // final timezone = data['timezone']; // Timezone handling might be needed depending on the package capabilities

    return Container(
        width: kTileUnitWidth,
        height: kTileUnitHeight,
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
        // Updated AnalogClock widget using flutter_analog_clock
        child: AnalogClock(),);
  }
}

class AnalogClock extends StatefulWidget {
  const AnalogClock({super.key});

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ClockPainter(time: DateTime.now()),
          size: const Size(kTileUnitWidth, kTileUnitHeight),
        );
      },
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime time;

  _ClockPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final radius = min(centerX, centerY);

    // --- Draw Clock Face ---
    final facePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, facePaint);

    // --- Draw Ticks and Numbers ---
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    const hourTickLength = 8.0;
    const minuteTickLength = 4.0;

    // We calculate the angle once and use it for both ticks and numbers
    for (int i = 0; i < 60; i++) {
      // *** THIS IS THE CORRECTED ANGLE CALCULATION ***
      // Rotate by -90 degrees (-pi/2) to start from 12 o'clock
      final angle = -pi / 2 + (i * 6) * pi / 180;
      final isHour = i % 5 == 0;

      // Set styles for the ticks
      final tickLength = isHour ? hourTickLength : minuteTickLength;
      tickPaint.strokeWidth = isHour ? 3 : 1.5;
      tickPaint.color = isHour ? Colors.black54 : Colors.grey.shade400;

      // Calculate tick positions using the unified angle
      final startPoint = Offset(
        centerX + (radius - tickLength) * cos(angle),
        centerY + (radius - tickLength) * sin(angle),
      );
      final endPoint = Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, tickPaint);

      // Draw Hour Numbers
      if (isHour) {
        final hour = i == 0 ? 12 : i ~/ 5;
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$hour',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20, // Adjust font size if needed for your container
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Calculate number position using the same unified angle
        final numberPosition = Offset(
          centerX + (radius - 20) * cos(angle),
          centerY + (radius - 20) * sin(angle),
        );

        // Center the number on its calculated position
        textPainter.paint(
            canvas,
            numberPosition -
                Offset(textPainter.width / 2, textPainter.height / 2));
      }
    }

    // --- Calculate Hand Angles (this part was already correct) ---
    final hourAngle =
        -pi / 2 + (time.hour % 12 + time.minute / 60) * (2 * pi / 12);
    final minuteAngle =
        -pi / 2 + (time.minute + time.second / 60) * (2 * pi / 60);
    final secondAngle = -pi / 2 + time.second * (2 * pi / 60);

    // --- Draw Hands (this part was already correct) ---
    final hourHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final minuteHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final secondHandPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final hourHandEnd = Offset(
      centerX + radius * 0.4 * cos(hourAngle),
      centerY + radius * 0.4 * sin(hourAngle),
    );
    canvas.drawLine(center, hourHandEnd, hourHandPaint);

    final minuteHandEnd = Offset(
      centerX + radius * 0.6 * cos(minuteAngle),
      centerY + radius * 0.6 * sin(minuteAngle),
    );
    canvas.drawLine(center, minuteHandEnd, minuteHandPaint);

    final secondHandEnd = Offset(
      centerX + radius * 0.8 * cos(secondAngle),
      centerY + radius * 0.8 * sin(secondAngle),
    );
    canvas.drawLine(center, secondHandEnd, secondHandPaint);

    // --- Draw Center Point (this part was already correct) ---
    final centerCirclePaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 6, centerCirclePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
