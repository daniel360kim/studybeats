import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/timer_swiper.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/todo_adder.dart';

class SessionInputs extends StatefulWidget {
  const SessionInputs({
    required this.onSessionInputsChanged,
    required this.showTimerEditor,
    required this.onSelectedTodosChanged,
    required this.onContinuePressed,
    super.key,
  });
  final ValueChanged<String> onSessionInputsChanged;
  final ValueChanged<bool> showTimerEditor;
  final ValueChanged<List<TodoItem>> onSelectedTodosChanged;
  final VoidCallback onContinuePressed;

  @override
  State<SessionInputs> createState() => _SessionInputsState();
}

class _SessionInputsState extends State<SessionInputs>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Timers for Focus and Break sessions.
  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);

  // At the beginning of _SessionInputsState
  List<TodoItem> _checkedTodoItems = [];

  final ScrollController _todoListScrollController = ScrollController();

  @override
  void dispose() {
    // Dispose of the scroll controller to free up resources.
    _todoListScrollController.dispose();
    super.dispose();
  }

  // New method to show a popup menu with the timer picker.
  void _showTimerPickerMenu({
    required GlobalKey key,
    required String pickerTitle,
    required int initialTime,
    required ValueChanged<int> onTimeChanged,
  }) async {
    // Determine the position of the tapped widget.
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height,
      offset.dx + size.width,
      offset.dy,
    );

    int temporaryMinutes = initialTime;

    // Await the result from the popup menu. It will return the selected minutes if OK is pressed,
    // or null if cancelled or dismissed.
    final int? result = await showMenu<int>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<int>(
          enabled: false, // Disable default selection behavior
          child: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 350, // adjust as needed
                height: 380, // adjust as needed
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and close button.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust $pickerTitle Timer',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kFlourishBlackish,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    // Timer editor
                    Expanded(
                      child: TimerSwiperItem(
                        hourLowerValue: 0,
                        hourUpperValue: 23,
                        minuteLowerValue: 0,
                        minuteUpperValue: 59,
                        initialHourValue: temporaryMinutes ~/ 60,
                        initialMinuteValue: temporaryMinutes % 60,
                        onDurationSelected: (duration) {
                          setState(() {
                            temporaryMinutes = duration.inMinutes;
                          });
                        },
                        child: Container(),
                      ),
                    ),
                    // Footer with Cancel and OK buttons.
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
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
                            onPressed: () {
                              Navigator.of(context).pop(temporaryMinutes);
                            },
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
              );
            },
          ),
        ),
      ],
    );

    if (result != null) {
      // Commit the change only if OK was pressed (i.e., result is not null).
      onTimeChanged(result);
    }
  }

  // Builds a time item that shows the time with a dropdown arrow.
  Widget _buildTimeItem({
    required String title,
    required int initialTimeMinutes,
  }) {
    // Create a GlobalKey to get the widget position on screen.
    final GlobalKey timeKey = GlobalKey();

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
        // Wrap the dropdown button in a container with the key.
        Container(
          key: timeKey,
          child: _TimeDropdownButton(
            minutes: initialTimeMinutes,
            onTap: () {
              _showTimerPickerMenu(
                key: timeKey,
                pickerTitle: title,
                initialTime: initialTimeMinutes,
                onTimeChanged: (newMinutes) {
                  setState(() {
                    if (title == 'Focus') {
                      studyTime = Duration(minutes: newMinutes);
                    } else if (title == 'Break') {
                      breakTime = Duration(minutes: newMinutes);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Builds the rest of the UI.
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
              SizedBox(
                height: 346,
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _todoListScrollController,
                  child: TodoAdder(
                    scrollController: _todoListScrollController,
                    selectedTodoItemIds:
                        _checkedTodoItems.map((todo) => todo.id).toList(),
                    onTodoItemToggled: (todoItem, bool isChecked) {
                      setState(() {
                        if (isChecked) {
                          if (!_checkedTodoItems
                              .any((t) => t.id == todoItem.id)) {
                            _checkedTodoItems.add(todoItem);
                          }
                        } else {
                          _checkedTodoItems
                              .removeWhere((t) => t.id == todoItem.id);
                        }

                        // Notify parent
                        widget.onSelectedTodosChanged(_checkedTodoItems);
                      });
                    },
                  ),
                ),
              ),
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
                    onPressed: widget.onContinuePressed,
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
        ),
        const SizedBox(width: 20),
        _buildTimeItem(
          title: 'Break',
          initialTimeMinutes: breakTime.inMinutes,
        ),
      ],
    );
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
              return Colors.black.withOpacity(0.1);
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
