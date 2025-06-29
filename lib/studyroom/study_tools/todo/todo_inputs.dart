import 'package:studybeats/api/todo/todo_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/theme_provider.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);

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
                  ? themeProvider.primaryAppColor.withOpacity(0.1)
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
                    color: _isHovering
                        ? themeProvider.primaryAppColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: _isHovering
                        ? Colors.white
                        : themeProvider.primaryAppColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'New task',
                  style: GoogleFonts.inter(
                    color: themeProvider.primaryAppColor,
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.enter) {
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
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: themeProvider.appContentBackgroundColor,
          border: Border.all(color: themeProvider.dividerColor, width: 1.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...buildInputFields(themeProvider),
            const SizedBox(height: 12.0),
            buildDateTimeButtons(themeProvider),
            const SizedBox(height: 4.0),
            Divider(color: themeProvider.dividerColor),
            const SizedBox(height: 4.0),
            buildButtons(themeProvider),
          ],
        ),
      ),
    );
  }

  List<Widget> buildInputFields(ThemeProvider themeProvider) {
    return [
      TextField(
        autofocus: true,
        controller: _titleController,
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        decoration: InputDecoration(
          hintText: 'Title',
          hintStyle: GoogleFonts.inter(
            color: themeProvider.secondaryTextColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          isDense: true,
          border: InputBorder.none,
        ),
        style: GoogleFonts.inter(
          color: themeProvider.mainTextColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        cursorColor: themeProvider.primaryAppColor,
      ),
      const SizedBox(height: 5.0),
      TextField(
        controller: _descriptionController,
        inputFormatters: [LengthLimitingTextInputFormatter(200)],
        decoration: InputDecoration(
          hintText: 'Description',
          hintStyle: GoogleFonts.inter(
            color: themeProvider.secondaryTextColor,
            fontSize: 12,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
        style: GoogleFonts.inter(
          color: themeProvider.mainTextColor,
          fontSize: 12,
        ),
        cursorColor: themeProvider.primaryAppColor,
      ),
    ];
  }

  Widget buildDateTimeButtons(ThemeProvider themeProvider) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: themeProvider.secondaryTextColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      side: BorderSide(
        color: themeProvider.inputBorderColor,
        width: 1,
      ),
      textStyle: GoogleFonts.inter(
        color: themeProvider.mainTextColor,
        fontSize: 14,
      ),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: () => _selectDate(context, themeProvider),
          style: buttonStyle,
          child: _selectedDate == null
              ? Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: themeProvider.secondaryTextColor,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text('Date',
                        style: TextStyle(color: themeProvider.mainTextColor)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('${_selectedDate!.toLocal()}'.split(' ')[0],
                        style: TextStyle(color: themeProvider.mainTextColor)),
                    const SizedBox(width: 2.0),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: themeProvider.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => _selectTime(context, themeProvider),
          style: buttonStyle,
          child: _selectedTime == null
              ? Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: themeProvider.secondaryTextColor,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text('Time',
                        style: TextStyle(color: themeProvider.mainTextColor)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(_selectedTime!.format(context),
                        style: TextStyle(color: themeProvider.mainTextColor)),
                    const SizedBox(width: 2.0),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedTime = null;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: themeProvider.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget buildButtons(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: widget.onClose,
          style: OutlinedButton.styleFrom(
            foregroundColor: themeProvider.secondaryTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            side: BorderSide(
              color: themeProvider.inputBorderColor,
              width: 1,
            ),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: themeProvider.mainTextColor,
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
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.primaryAppColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Text(
            'Create',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _selectDate(BuildContext context, ThemeProvider themeProvider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: themeProvider.isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: themeProvider.primaryAppColor,
                    onPrimary: Colors.white,
                    surface: themeProvider.popupBackgroundColor,
                    onSurface: themeProvider.mainTextColor,
                  ), dialogTheme: DialogThemeData(backgroundColor: themeProvider.popupBackgroundColor),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: themeProvider.primaryAppColor,
                    onPrimary: Colors.white,
                    onSurface: themeProvider.mainTextColor,
                  ), dialogTheme: DialogThemeData(backgroundColor: themeProvider.popupBackgroundColor),
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

  void _selectTime(BuildContext context, ThemeProvider themeProvider) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: themeProvider.isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: themeProvider.primaryAppColor,
                    onPrimary: Colors.white,
                    surface: themeProvider.popupBackgroundColor,
                    onSurface: themeProvider.mainTextColor,
                  ),
                  timePickerTheme: TimePickerThemeData(
                    backgroundColor: themeProvider.popupBackgroundColor,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: themeProvider.primaryAppColor,
                    onPrimary: Colors.white,
                    onSurface: themeProvider.mainTextColor,
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
