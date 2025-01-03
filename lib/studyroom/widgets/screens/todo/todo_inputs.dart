import 'package:flourish_web/api/todo/todo_item.dart';
import 'package:flourish_web/api/todo/todo_service.dart';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

class AddTaskButton extends StatefulWidget {
  const AddTaskButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  State<AddTaskButton> createState() => _AddTaskButtonState();
}

class _AddTaskButtonState extends State<AddTaskButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _isHovering = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isHovering = false;
          });
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isHovering
                  ? kFlourishAdobe.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _isHovering ? kFlourishAdobe : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: _isHovering ? kFlourishAliceBlue : kFlourishAdobe,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'New task',
                  style: GoogleFonts.inter(
                    color: kFlourishAdobe,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateNewTaskInputs extends StatefulWidget {
  const CreateNewTaskInputs(
      {super.key,
      required this.onCreateTask,
      required this.onClose,
      required this.onError});
  final ValueChanged<TodoItem> onCreateTask;
  final VoidCallback onClose;
  final VoidCallback onError;

  @override
  State<CreateNewTaskInputs> createState() => _CreateNewTaskInputsState();
}

class _CreateNewTaskInputsState extends State<CreateNewTaskInputs> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      setState(() {});
    });
    _descriptionController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ...buildInputFields(),
          const SizedBox(height: 12.0),
          buildDateTimeButtons(),
          const SizedBox(height: 4.0),
          const Divider(),
          const SizedBox(height: 4.0),
          buildButtons(),
        ],
      ),
    );
  }

  List<Widget> buildInputFields() {
    return [
      TextField(
        controller: _titleController,
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        decoration: InputDecoration(
          hintText: 'Title',
          hintStyle: GoogleFonts.inter(
            color: kFlourishLightBlackish,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          isDense: true,
          border: InputBorder.none,
        ),
        style: GoogleFonts.inter(
          color: kFlourishEmphasisBlackish,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        cursorColor: kFlourishBlackish,
      ),
      const SizedBox(height: 5.0),
      TextField(
        controller: _descriptionController,
        inputFormatters: [LengthLimitingTextInputFormatter(200)],
        decoration: InputDecoration(
          hintText: 'Description',
          hintStyle: GoogleFonts.inter(
            color: kFlourishLightBlackish,
            fontSize: 12,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
        style: GoogleFonts.inter(
          color: kFlourishEmphasisBlackish,
          fontSize: 12,
        ),
        cursorColor: kFlourishBlackish,
      ),
    ];
  }

  Widget buildDateTimeButtons() {
    final buttonStyle = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(Colors.grey[600]),
      padding: WidgetStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6), // Minimal padding
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Less rounded
        ),
      ),
      side: WidgetStateProperty.all<BorderSide>(
        BorderSide(
          color: Colors.grey.withOpacity(0.6), // Subtle border color
          width: 1, // Thin border
        ),
      ),
      textStyle: WidgetStateProperty.all<TextStyle>(
        GoogleFonts.inter(
          color: kFlourishBlackish.withOpacity(0.8), // Less intense color
          fontSize: 14,
        ),
      ),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: () => _selectDate(context),
          style: buttonStyle,
          child: _selectedDate == null
              ? Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    const Text('Date'),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('${_selectedDate!.toLocal()}'.split(' ')[0]),
                    const SizedBox(width: 2.0),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => _selectTime(context),
          style: buttonStyle,
          child: _selectedTime == null
              ? Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    const Text('Time'),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(_selectedTime!.format(context)),
                    const SizedBox(width: 2.0),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedTime = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget buildButtons() {
    final buttonStyle = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(Colors.grey[600]),
      padding: WidgetStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6), // Minimal padding
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Less rounded
        ),
      ),
      side: WidgetStateProperty.all<BorderSide>(
        BorderSide(
          color: Colors.grey.withOpacity(0.6), // Subtle border color
          width: 1, // Thin border
        ),
      ),
      textStyle: WidgetStateProperty.all<TextStyle>(
        GoogleFonts.inter(
          color: kFlourishBlackish.withOpacity(0.8), // Less intense color
          fontSize: 14,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: widget.onClose,
          style: buttonStyle,
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: kFlourishBlackish.withOpacity(0.8), // Less intense color
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            final newTodo = TodoItem(
              id: const Uuid().v4(),
              title: _titleController.text,
              description: _descriptionController.text,
              isDone: false,
              isFavorite: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dueDate: _selectedDate,
              dueTime: _selectedTime,
            );

            widget.onCreateTask(newTodo);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(kFlourishAdobe),
            padding: WidgetStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6), // Minimal padding
            ),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0), // Less rounded
              ),
            ),
          ),
          child: Text(
            'Create',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: kFlourishAdobe, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Text color for selectable days
              surface: Colors.grey.shade200, // Background for selected date
            ),
            dialogBackgroundColor: Colors.white, // Dialog background color
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white, // Picker background
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kFlourishBlackish, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: kFlourishBlackish, // Text color in the picker
            ),
            dialogBackgroundColor: Colors.white, // Dialog background color
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: kFlourishBlackish, // Cursor color
              selectionColor:
                  Colors.grey.shade300, // Text selection highlight color
              selectionHandleColor: kFlourishBlackish, // Selection handle color
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white, // Picker background
              hourMinuteTextColor:
                  kFlourishBlackish, // Text color for hour and minute
              dayPeriodTextColor: kFlourishBlackish, // AM/PM text color
              dayPeriodColor: kFlourishAdobe,
              hourMinuteColor: Colors.grey.shade200, // Hour/minute background
              dialBackgroundColor: Colors.white, // Dial background
              dialHandColor: kFlourishAdobe, // Dial hand color
              dialTextColor: kFlourishBlackish, // Dial text color
              entryModeIconColor:
                  kFlourishBlackish, // Icon color for switching modes
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      if (_selectedDate == null) {
        setState(() {
          _selectedDate = DateTime.now();
        });
      }
    }
  }
}
