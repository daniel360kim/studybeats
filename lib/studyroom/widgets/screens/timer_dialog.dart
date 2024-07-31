import 'dart:async';
import 'dart:ui';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'timer.dart';

class TimerDialog extends StatefulWidget {
  const TimerDialog({
    required this.focusTimerDuration,
    required this.breakTimerDuration,
    required this.fontFamily,
    required this.onExit,
    super.key,
  });

  final Duration focusTimerDuration;
  final Duration breakTimerDuration;
  final String fontFamily;
  final ValueChanged<PomodoroDurations> onExit;

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  late Timer _timer;
  late Duration _currentTime;

  bool _isOnFocus = true;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.focusTimerDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  void _updateTimer(Timer timer) {
    setState(() {
      if (_currentTime.inSeconds > 0) {
        _currentTime = _currentTime - const Duration(seconds: 1);
      } else {
        _isOnFocus = !_isOnFocus;
        _currentTime =
            _isOnFocus ? widget.focusTimerDuration : widget.breakTimerDuration;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Dispose the timer to prevent memory leaks
    super.dispose();
  }

  String _formattedTime(Duration duration) {
    final hours = duration.inHours > 0
        ? '${duration.inHours.toString().padLeft(2, '0')}:'
        : '';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 150,
        width: _currentTime.inHours > 0 ? 300 : 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Colors.black.withOpacity(0.5),
        ),
        child: Stack(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 25),
                      IconButton(
                        onPressed: () {
                          PomodoroDurations resettedDurations =
                              PomodoroDurations(Duration.zero, Duration.zero);
                          widget.onExit(resettedDurations);
                        },
                        padding: EdgeInsets.zero,
                        color: kFlourishLightBlackish,
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _isOnFocus ? 'Focus' : 'Break',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              fontFamily: widget.fontFamily,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 60, // to match the width of the IconButton
                      ),
                    ],
                  ),
                  Text(
                    _formattedTime(_currentTime),
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Inter',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
