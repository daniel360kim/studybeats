import 'package:flutter/material.dart';

class VolumeBar extends StatefulWidget {
  const VolumeBar(
      {required this.initialVolume, required this.onChanged, super.key});

  final double initialVolume;
  final ValueChanged<double>? onChanged;

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
    return RotatedBox(
      quarterTurns: 3,
      child: SizedBox(
        width: 150,
        child: Slider(
          value: _value,
          onChanged: (value) {
            setState(() {
              _value = value;
            });
            widget.onChanged!(value);
          },
          min: 0,
          max: 100,
          label: 'Volume',
        ),
      ),
    );
  }
}
