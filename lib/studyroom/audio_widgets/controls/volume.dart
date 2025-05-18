import 'package:flutter/material.dart';

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({required this.volumeChanged, super.key});

  final Function volumeChanged;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double volume = 1.0;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              onPressed: () {
                setState(() {
                  volume = 0.0;
                  widget.volumeChanged(0.0);
                });
              },
              icon: const Icon(Icons.volume_off_rounded),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
              inactiveTrackColor: const Color.fromRGBO(32, 32, 32, 0.5),
              activeTrackColor: const Color.fromRGBO(66, 66, 66, 1.0),
              thumbColor: const Color.fromRGBO(45, 45, 45,
                  1.0), // color of the whole track (past the current pos and buffer)
            ),
            child: SizedBox(
              width: 80,
              child: Slider(
                min: 0.0,
                max: 1.0,
                value: volume,
                onChanged: (double value) {
                  setState(() {
                    volume = value;
                    widget.volumeChanged(value);
                  });
                },
              ),
            ),
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              onPressed: () {
                setState(() {
                  volume = 1.0;
                  widget.volumeChanged(1.0);
                });
              },
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
