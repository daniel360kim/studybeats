import 'dart:async';
import 'dart:ui';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/timer_fx/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer_player.dart';
import 'package:flutter/material.dart';
import 'timer.dart';

class TabDescriptionReporter {
  bool isFocus;
  Duration duration;

  TabDescriptionReporter({required this.isFocus, required this.duration});
}

class TimerDialog extends StatefulWidget {
  const TimerDialog({
    required this.focusTimerDuration,
    required this.breakTimerDuration,
    required this.onExit,
    required this.timerSoundEnabled,
    required this.timerFxData,
    required this.onTimerDurationChanged,
    super.key,
  });

  final Duration focusTimerDuration;
  final Duration breakTimerDuration;
  final ValueChanged<PomodoroDurations> onExit;
  final bool timerSoundEnabled;
  final ValueChanged<TabDescriptionReporter> onTimerDurationChanged;
  final TimerFxData timerFxData;

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  late Timer _timer;
  late DateTime _startTime;
  late Duration _initialTime;

  Duration _currentTime = Duration.zero;
  bool _isOnFocus = true;

  final _soundPlayer = TimerPlayer();
  final _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _sendAnalytics();
    _soundPlayer.init();
    _startFocusTimer();
  }

  void _sendAnalytics() async {
    await _analyticsService.logOpenFeature(
        ContentType.studyTimer, 'Study Timer');
  }

  void _startFocusTimer() {
    _currentTime = widget.focusTimerDuration;
    _startTimer();
  }

  void _startBreakTimer() {
    _currentTime = widget.breakTimerDuration;
    _startTimer();
  }

  void _startTimer() {
    _initialTime = _currentTime;
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  @override
  void dispose() {
    _timer.cancel(); // Dispose the timer to prevent memory leaks
    _soundPlayer.dispose();
    super.dispose();
  }

  void _updateTimer(Timer timer) {
    final elapsed = DateTime.now().difference(_startTime);
    final remainingTime = _initialTime - elapsed;

    final report =
        TabDescriptionReporter(isFocus: _isOnFocus, duration: remainingTime);
    widget.onTimerDurationChanged(report);

    if (remainingTime.inSeconds <= 0) {
      setState(() {
        _isOnFocus = !_isOnFocus;
        if (_isOnFocus) {
          _startFocusTimer();
        } else {
          _startBreakTimer();
        }
        if (widget.timerSoundEnabled) {
          _soundPlayer.playTimerSound(widget.timerFxData);
        }
      });
    } else {
      setState(() {
        _currentTime = remainingTime;
      });
    }
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

                          _timer.cancel();
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
                              color: kFlourishAliceBlue,
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
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
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
