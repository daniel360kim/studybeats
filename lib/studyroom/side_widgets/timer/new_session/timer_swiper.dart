import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';

class TimerSwiperItem extends StatefulWidget {
  const TimerSwiperItem({
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
  late Duration _hourTimer;
  late Duration _minuteTimer;
  @override
  void initState() {
    _hourTimer = Duration(hours: widget.initialHourValue);
    _minuteTimer = Duration(minutes: widget.initialMinuteValue);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
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
