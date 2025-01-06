import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class VolumeBar extends StatefulWidget {
  const VolumeBar(
      {required this.initialVolume,
      required this.onChanged,
      required this.icon,
      required this.themeColor,
      super.key});

  final double initialVolume;
  final ValueChanged<double>? onChanged;
  final IconData icon;
  final Color themeColor;

  @override
  State<VolumeBar> createState() => _VolumeBarState();
}

class _VolumeBarState extends State<VolumeBar> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialVolume;
  }

  @override
  Widget build(BuildContext context) {
    return IconSlider(
      icon: widget.icon,
      themeColor: widget.themeColor,
      value: _value,
      onChanged: (value) {
        setState(() {
          _value = value;
        });
        widget.onChanged?.call(value);
      },
    );
  }
}

class IconSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final IconData icon;
  final Color themeColor;

  const IconSlider({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.themeColor,
    super.key,
  });

  @override
  _IconSliderState createState() => _IconSliderState();
}

class _IconSliderState extends State<IconSlider> {
  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: CustomIconSliderThumb(icon: widget.icon),
      ),
      child: Slider(
        activeColor: widget.themeColor,
        thumbColor: widget.themeColor,
        inactiveColor: kFlourishLightBlackish,
        value: widget.value,
        onChanged: widget.onChanged,
        min: 0,
        max: 200,
        label: '${widget.value.round()}',
      ),
    );
  }
}

class CustomIconSliderThumb extends SliderComponentShape {
  final IconData icon;

  CustomIconSliderThumb({required this.icon});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(30, 30); // Size of the icon
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.blue
      ..style = PaintingStyle.fill;

    // Draw the icon
    canvas.drawCircle(center, 15, paint); // Background circle
    TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: textDirection,
    );

    iconPainter.layout();
    iconPainter.paint(
        canvas, center - Offset(iconPainter.width / 2, iconPainter.height / 2));
  }
}
