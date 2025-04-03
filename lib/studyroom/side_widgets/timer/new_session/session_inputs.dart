import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/timer_swiper.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/todo_adder.dart';

class SessionInputs extends StatefulWidget {
  const SessionInputs(
      {required this.onSessionInputsChanged,
      required this.onContinue,
      required this.showTimerEditor,
      super.key});
  final ValueChanged<String> onSessionInputsChanged;
  final VoidCallback onContinue;
  final ValueChanged<bool> showTimerEditor;

  @override
  State<SessionInputs> createState() => _SessionInputsState();
}

class _SessionInputsState extends State<SessionInputs>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);

  // State variables for the custom timer editor dialog.
  bool _isPickerVisible = false;
  String _pickerTitle = '';
  int _initialTime = 0;
  ValueChanged<int>? _onTimeChanged;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // adjust duration as desired
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // This method triggers the custom timer editor dialog.
  void _showTimePicker(
      String title, int initialTime, ValueChanged<int> onTimeChanged) {
    widget.showTimerEditor(true);
    setState(() {
      _pickerTitle = title;
      _initialTime = initialTime;
      _onTimeChanged = onTimeChanged;
      _isPickerVisible = true;
    });
    _animationController.forward();
  }

  // Hide the dialog by reversing the animation.
  void _hideTimePicker() {
    widget.showTimerEditor(false);
    _animationController.reverse().then((_) {
      setState(() {
        _isPickerVisible = false;
      });
    });
  }

  // Build the timer editor overlay using FadeTransition and SlideTransition.
  Widget _buildTimerEditor() {
    if (!_isPickerVisible) return const SizedBox.shrink();
    return Stack(
      children: [
        // Darkened background
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _hideTimePicker, // dismiss when tapping outside
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Bottom-up sliding editor dialog
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 370,
                child: Wrap(
                  children: [
                    // Header with title and close button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust $_pickerTitle Timer',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kFlourishBlackish,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _hideTimePicker,
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    const Divider(height: 1, thickness: 1),
                    // Timer editor
                    Expanded(
                      child: TimerSwiperItem(
                        hourLowerValue: 0,
                        hourUpperValue: 23,
                        minuteLowerValue: 0,
                        minuteUpperValue: 59,
                        initialHourValue: _initialTime ~/ 60,
                        initialMinuteValue: _initialTime % 60,
                        onDurationSelected: (duration) {
                          if (_onTimeChanged != null) {
                            _onTimeChanged!(duration.inMinutes);
                          }
                        },
                        child: Container(),
                      ),
                    ),
                    // Footer with Cancel and OK buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _hideTimePicker,
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _hideTimePicker,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              backgroundColor: kFlourishAdobe,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'OK',
                              style: GoogleFonts.inter(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Builds a time item that shows the time and a dropdown arrow.
  Widget _buildTimeItem({
    required String title,
    required int initialTimeMinutes,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),
        Container(
          width: 50,
          height: 2,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 10),
        _TimeDropdownButton(minutes: initialTimeMinutes, onTap: onTap),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Name',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish),
              ),
              const SizedBox(height: 10),
              _buildTextField(),
              const SizedBox(height: 20),
              _buildTimerSetters(),
              const SizedBox(height: 20),
              Text(
                'Add tasks',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish),
              ),
              const SizedBox(height: 10),
              _buildTaskBuilder(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      backgroundColor: kFlourishAdobe,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.onContinue,
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Overlay the custom timer editor if visible.
        _buildTimerEditor(),
      ],
    );
  }

  TextField _buildTextField() {
    return TextField(
      style: const TextStyle(color: kFlourishBlackish),
      decoration: InputDecoration(
        hintText: 'Enter a name for your session',
        hintStyle:
            GoogleFonts.inter(color: kFlourishLightBlackish, fontSize: 14),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kFlourishLightBlackish),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kFlourishBlackish),
        ),
      ),
      cursorColor: kFlourishBlackish,
      onChanged: (value) {
        widget.onSessionInputsChanged(value);
      },
    );
  }

  Widget _buildTimerSetters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeItem(
          title: 'Focus',
          initialTimeMinutes: studyTime.inMinutes,
          onTap: () {
            _showTimePicker('Focus', studyTime.inMinutes, (newMinutes) {
              setState(() {
                studyTime = Duration(minutes: newMinutes);
              });
            });
          },
        ),
        const SizedBox(width: 20),
        _buildTimeItem(
          title: 'Break',
          initialTimeMinutes: breakTime.inMinutes,
          onTap: () {
            _showTimePicker('Break', breakTime.inMinutes, (newMinutes) {
              setState(() {
                breakTime = Duration(minutes: newMinutes);
              });
            });
          },
        ),
      ],
    );
  }

  Widget _buildTaskBuilder() {
    return TodoAdder();
  }
}

class _TimeDropdownButton extends StatelessWidget {
  final int minutes;
  final VoidCallback onTap;

  const _TimeDropdownButton({required this.minutes, required this.onTap});

  String _formatDuration(int totalMinutes) {
    final duration = Duration(minutes: totalMinutes);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return kFlourishBlackish.withOpacity(0.1);
            }
            return null;
          },
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(minutes),
            style: GoogleFonts.inter(fontSize: 28, color: Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: Colors.grey[600],
            size: 28,
          ),
        ],
      ),
    );
  }
}
