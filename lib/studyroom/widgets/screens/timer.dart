import 'package:card_swiper/card_swiper.dart';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class PomodoroDurations {
  Duration studyTime;
  Duration breakTime;

  PomodoroDurations(this.studyTime, this.breakTime);
}

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({
    required this.onStartPressed,
    super.key,
  });

  final ValueChanged<PomodoroDurations> onStartPressed;

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  final SwiperController _swiperController = SwiperController();

  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);
  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius borderRadius = BorderRadius.only(
      topLeft: Radius.circular(40.0),
      topRight: Radius.circular(40.0),
    );
    return SizedBox(
      width: 300,
      height: 400,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: const BoxDecoration(
                  color: Color.fromRGBO(170, 170, 170, 0.7),
                  borderRadius: borderRadius),
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
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: kFlourishBlackish,
                              fontSize: 15,
                              fontFamily: 'Inter',
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
                              color: kFlourishAliceBlue,
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () => _swiperController.previous(),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: kFlourishBlackish,
                                backgroundColor: kFlourishCyan,
                                overlayColor:
                                    kFlourishBlackish.withOpacity(0.1),
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
                              child: const Text(
                                'Start',
                                style: TextStyle(
                                  color: kFlourishBlackish,
                                  fontSize: 15,
                                  fontFamily: 'Inter',
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
            ),
          ),
        ),
      ),
    );
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
              style: const TextStyle(
                fontSize: 30,
                fontFamily: 'Inter',
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
                        width: 50,
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
                        width: 50,
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
        itemExtent: 50,
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
          style: TextStyle(
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
