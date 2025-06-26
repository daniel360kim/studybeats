import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class VolumeBar extends StatefulWidget {
  const VolumeBar({
    required this.initialVolume,
    required this.onChanged,
    required this.icon,
    required this.themeColor,
    super.key,
  });

  final double initialVolume;
  final ValueChanged<double>? onChanged;
  final IconData icon;
  final Color themeColor;

  @override
  State<VolumeBar> createState() => _VolumeBarState();
}

class _VolumeBarState extends State<VolumeBar> {
  late double _value;
  bool get _isEnabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _value = widget.initialVolume;
  }

  // Update slider value if the initialVolume prop changes
  @override
  void didUpdateWidget(covariant VolumeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVolume != oldWidget.initialVolume) {
      setState(() {
        _value = widget.initialVolume;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isEnabled ? 1.0 : 0.4,
      child: _IconSlider(
        icon: widget.icon,
        themeColor: _isEnabled ? widget.themeColor : Colors.grey,
        value: _value,
        onChanged: (value) {
          if (!_isEnabled) return;
          setState(() {
            _value = value;
          });
          widget.onChanged?.call(value);
        },
      ),
    );
  }
}

class _IconSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final IconData icon;
  final Color themeColor;

  const _IconSlider({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: themeColor,
        inactiveTrackColor: kFlourishLightBlackish.withOpacity(0.5),
        thumbColor: themeColor,
        thumbShape: CustomIconSliderThumb(icon: icon, color: themeColor),
        trackShape: const RoundedRectSliderTrackShape(),
        trackHeight: 6.0,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: 0,
        max: 100,
      ),
    );
  }
}

class CustomIconSliderThumb extends SliderComponentShape {
  final IconData icon;
  final Color color;

  CustomIconSliderThumb({required this.icon, required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(28, 28);
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
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 14, paint);

    TextPainter iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    iconPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 18,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );

    iconPainter.layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }
}
