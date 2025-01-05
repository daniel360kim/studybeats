import 'package:card_swiper/card_swiper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/timer_fx/objects.dart';
import 'package:studybeats/api/timer_fx/timer_fx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/studytools/timer/timer_player.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PomodoroDurations {
  Duration studyTime;
  Duration breakTime;

  PomodoroDurations(this.studyTime, this.breakTime);
}

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({
    required this.onClose,
    required this.onStartPressed,
    required this.onTimerSoundEnabled,
    required this.onTimerSoundSelected,
    super.key,
  });

  final ValueChanged<PomodoroDurations> onStartPressed;
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<TimerFxData> onTimerSoundSelected;
  final VoidCallback onClose;

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  final SwiperController _swiperController = SwiperController();

  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);

  List<TimerFxData> _timerFxList = [];
  TimerFxData? _selectedTimerFx;

  final TimerPlayer _timerPlayer = TimerPlayer();

  final TimerFxService _timerFxService = TimerFxService();

  bool _error = false; // TODO handle error
  String? _errorMessage;
  bool _enableTimerSound = true;

  @override
  void initState() {
    super.initState();
    getTimerSoundFx();
    _timerPlayer.init();
  }

  void getTimerSoundFx() async {
    try {
      final timerFxList = await _timerFxService.getTimerFxData();
      if (timerFxList.isNotEmpty) {
        setState(() {
          _timerFxList = timerFxList;
          _selectedTimerFx = timerFxList.first;

          widget.onTimerSoundEnabled(_enableTimerSound);
          widget.onTimerSoundSelected(_selectedTimerFx!);
        });
      } else {
        setState(() {
          _error = true;
          _errorMessage = 'No timer sound effects found';
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = 'Error loading timer sound effects';
      });
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _timerPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _error
        ? SizedBox(
            width: 300,
            height: MediaQuery.of(context).size.height - 80,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                    Color(0xFFE0E7FF),
                    Color(0xFFF7F8FC),
                  ])),
              child: Column(
                children: [
                  buildTopBar(),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        : SizedBox(
            width: 300,
            height: MediaQuery.of(context).size.height - 80,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                    Color(0xFFE0E7FF),
                    Color(0xFFF7F8FC),
                  ])),
              child: Column(
                children: [
                  buildTopBar(),
                  buildTimerSwiper(),
                  buildSoundFxSelector(),
                ],
              ),
            ),
          );
  }

  Widget buildTopBar() {
    return Container(
      height: 40,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget buildTimerSwiper() {
    return Container(
      height: 390,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Swiper(
        itemCount: 2,
        loop: false,
        itemWidth: 80,
        itemHeight: 50,
        physics: const NeverScrollableScrollPhysics(),
        controller: _swiperController,
        itemBuilder: (BuildContext context, int index) {
          switch (index) {
            case 0:
              return TimerSwiperItem(
                title: 'Study Time',
                hourLowerValue: 0,
                hourUpperValue: 24,
                minuteLowerValue: 0,
                minuteUpperValue: 59,
                initialHourValue: 0,
                initialMinuteValue: 25,
                onDurationSelected: (value) {
                  studyTime = value;
                },
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: kFlourishBlackish,
                    backgroundColor: kFlourishCyan,
                    overlayColor: kFlourishBlackish.withOpacity(0.1),
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => _swiperController.next(),
                  child: Text(
                    'Next',
                    style: GoogleFonts.inter(
                      color: kFlourishBlackish,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            case 1:
              return TimerSwiperItem(
                title: 'Break Time',
                hourLowerValue: 0,
                hourUpperValue: 24,
                minuteLowerValue: 0,
                minuteUpperValue: 59,
                initialHourValue: 0,
                initialMinuteValue: 5,
                onDurationSelected: (value) {
                  breakTime = value;
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      color: kFlourishBlackish,
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _swiperController.previous(),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: kFlourishBlackish,
                        backgroundColor: kFlourishCyan,
                        overlayColor: kFlourishBlackish.withOpacity(0.1),
                        minimumSize: const Size(125, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        PomodoroDurations durations =
                            PomodoroDurations(studyTime, breakTime);
                        widget.onStartPressed(durations);
                      },
                      child: Text(
                        'Start',
                        style: GoogleFonts.inter(
                          color: kFlourishBlackish,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            default:
              return const Placeholder();
          }
        },
      ),
    );
  }

  Widget buildSoundFxSelector() {
    if (_enableTimerSound) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _enableTimerSound = !_enableTimerSound;
              });
              widget.onTimerSoundEnabled(_enableTimerSound);
            },
            icon: Icon(
              _enableTimerSound
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: kFlourishBlackish,
            ),
          ),
          const SizedBox(width: 10),
          _timerFxList.isEmpty
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: kFlourishBlackish,
                  ),
                )
              : Container(
                  height: 30,
                  width: 170,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: kFlourishLightBlackish,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: kFlourishBlackish.withOpacity(0.1),
                        spreadRadius: 5,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: kFlourishBlackish.withOpacity(0.1),
                    ),
                  ),
                  child: DropdownButton<TimerFxData>(
                    value: _selectedTimerFx,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 24,
                    elevation: 16,
                    underline: Container(
                      height: 0,
                      color: Colors.transparent,
                    ),
                    items: _timerFxList
                        .map((TimerFxData timerFxData) =>
                            DropdownMenuItem<TimerFxData>(
                              value: timerFxData,
                              child: Row(
                                children: [
                                  Text(
                                    timerFxData.name,
                                    style: GoogleFonts.inter(
                                      color: kFlourishBlackish,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (TimerFxData? timerFxData) {
                      if (timerFxData == null) return;
                      setState(() {
                        _selectedTimerFx = timerFxData;
                      });

                      _timerPlayer.playTimerSound(timerFxData);
                      widget.onTimerSoundSelected(timerFxData);
                    },
                  ),
                ),
        ],
      );
    } else {
      return IconButton(
        onPressed: () {
          setState(() {
            _enableTimerSound = !_enableTimerSound;
          });
          widget.onTimerSoundEnabled(_enableTimerSound);
        },
        icon: Icon(
          Icons.notifications_off,
          color: kFlourishBlackish,
        ),
      );
    }
  }
}

class TimerSwiperItem extends StatefulWidget {
  const TimerSwiperItem({
    required this.title,
    required this.hourLowerValue,
    required this.hourUpperValue,
    required this.minuteLowerValue,
    required this.minuteUpperValue,
    required this.onDurationSelected, // Add this callback
    this.initialHourValue = 0,
    this.initialMinuteValue = 0,
    required this.child,
    super.key,
  });

  final String title;
  final int hourLowerValue;
  final int hourUpperValue;
  final int minuteLowerValue;
  final int minuteUpperValue;
  final int initialHourValue;
  final int initialMinuteValue;
  final Widget child;

  final ValueChanged<Duration>
      onDurationSelected; // Callback for selected duration

  @override
  State<TimerSwiperItem> createState() => _TimerSwiperItemState();
}

class _TimerSwiperItemState extends State<TimerSwiperItem> {
  Duration _hourTimer = const Duration();
  Duration _minuteTimer = const Duration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Text(widget.title,
              style: GoogleFonts.inter(
                fontSize: 30,
                color: kFlourishBlackish,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 20),
          Stack(
            children: [
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 75),
                    Container(
                      height: 50,
                      width: 200,
                      alignment: Alignment.bottomCenter,
                      decoration: BoxDecoration(
                        color: kFlourishAliceBlue.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: kFlourishBlackish.withOpacity(0.1),
                            spreadRadius: 5,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        height: 200,
                        width: 60,
                        child: TimeSlider(
                          lowerValue: widget.hourLowerValue,
                          upperValue: widget.hourUpperValue,
                          initialTimeValue: widget.initialHourValue,
                          onTimeSelected: (selectedTime) {
                            setState(() {
                              _hourTimer = Duration(hours: selectedTime);
                              Duration timer = _hourTimer + _minuteTimer;
                              widget.onDurationSelected(
                                  timer); // Call the callback
                            });
                          },
                        )),
                    Text('H', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 20),
                    SizedBox(
                        height: 200,
                        width: 60,
                        child: TimeSlider(
                          lowerValue: widget.minuteLowerValue,
                          upperValue: widget.minuteUpperValue,
                          initialTimeValue: widget.initialMinuteValue,
                          onTimeSelected: (selectedTime) {
                            setState(() {
                              _minuteTimer = Duration(minutes: selectedTime);
                              Duration timer = _hourTimer + _minuteTimer;
                              widget.onDurationSelected(
                                  timer); // Call the callback
                            });
                          },
                        )),
                    Text('M', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          widget.child,
        ],
      ),
    );
  }
}

class TimeSlider extends StatefulWidget {
  const TimeSlider(
      {required this.lowerValue,
      required this.upperValue,
      required this.onTimeSelected,
      this.initialTimeValue = 0,
      super.key});

  final int lowerValue;
  final int upperValue;
  final int initialTimeValue;

  final ValueChanged<int> onTimeSelected;
  @override
  State<TimeSlider> createState() => _TimeSliderState();
}

class _TimeSliderState extends State<TimeSlider> {
  late List<int> numbers;

  late int _selectedHourIndex; // Track the selected hour index
  FixedExtentScrollController controller = FixedExtentScrollController();

  @override
  void initState() {
    super.initState();

    _selectedHourIndex = widget.initialTimeValue;
    numbers = List.generate(widget.upperValue - widget.lowerValue + 1,
        (index) => widget.lowerValue + index);
    controller = FixedExtentScrollController(initialItem: _selectedHourIndex);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> hoursWidgets = List.generate(
      numbers.length,
      (index) => _buildHourWidget(index),
    );

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        controller.jumpTo(controller.offset - details.primaryDelta! * 1.15);
      },
      child: ListWheelScrollView(
        controller: controller,
        physics: const FixedExtentScrollPhysics(),
        itemExtent: 60,
        onSelectedItemChanged: (int index) {
          setState(() {
            _selectedHourIndex = index;
            widget.onTimeSelected(numbers[index]);
          });
        },
        children: hoursWidgets,
      ),
    );
  }

  Widget _buildHourWidget(int index) {
    Color textColor = index == _selectedHourIndex
        ? kFlourishBlackish
        : kFlourishBlackish.withOpacity(0.5);

    String number = '';
    if (index < 10) {
      number = '0${numbers[index]}';
    } else {
      number = numbers[index].toString();
    }
    return Container(
      alignment: Alignment.center,
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 40,
            color: textColor,
          ),
          children: [
            TextSpan(text: number),
          ],
        ),
      ),
    );
  }
}
