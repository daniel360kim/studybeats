import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoItemTile extends StatefulWidget {
  const TodoItemTile(
      {required this.item,
      required this.onItemMarkedAsDone,
      required this.onItemDetailsChanged,
      required this.onItemDateTimeChanged,
      required this.onPriorityChanged,
      super.key});

  final TodoItem item;
  final VoidCallback onItemMarkedAsDone;
  final ValueChanged<TodoItem> onItemDetailsChanged;
  final ValueChanged<TodoItem> onItemDateTimeChanged;
  final ValueChanged<TodoItem> onPriorityChanged;

  @override
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  bool _titleTextFieldHighlighted = false;
  bool _descriptionTextFieldHighlighted = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController =
        TextEditingController(text: widget.item.description);

    setState(() {
      _selectedDate = widget.item.dueDate;
      _selectedTime = widget.item.dueTime;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveChanges() {
    setState(() {
      widget.item.title = _titleController.text;
      widget.item.description = _descriptionController.text;
      widget.item.dueDate = _selectedDate;
      widget.item.dueTime = _selectedTime;

      widget.onItemDetailsChanged(widget.item);
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = widget.item.title;
      _descriptionController.text = widget.item.description ?? '';
      _selectedDate = widget.item.dueDate;
      _selectedTime = widget.item.dueTime;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isEditing) {
          return;
        }
        _toggleEditMode();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _isHovering || _isEditing
                  ? kFlourishLightBlackish.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Column(
              children: [
                buildTitle(),
                if (widget.item.description != null &&
                    widget.item.description!.isNotEmpty &&
                    !_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(widget.item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          )),
                    ),
                  ),
                if (_isEditing) buildEditControls(),
                if (widget.item.dueDate != null) buildDeadlineDescription(),
                if (_isEditing) buildEditSaveControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTitle() {
    return Row(
      children: [
        Checkbox(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          value: widget.item.isDone,
          activeColor: kFlourishAdobe,
          onChanged: (value) {
            widget.onItemMarkedAsDone();
            setState(() {
              widget.item.isDone = value!;
            });
          },
        ),
        if (widget.item.isFavorite)
          const Icon(
            Icons.flag,
            size: 12,
            color: Colors.red,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: _isEditing
              ? TextFormField(
                  onTap: () {
                    if (!_titleTextFieldHighlighted) {
                      _titleController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _titleController.text.length,
                      );
                      setState(() {
                        _titleTextFieldHighlighted = true;
                      });
                    } else {
                      setState(() {
                        _titleTextFieldHighlighted = false;
                      });
                    }
                  },
                  scrollPadding: EdgeInsets.zero,
                  controller: _titleController,
                  cursorColor: kFlourishBlackish,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter title',
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kFlourishBlackish,
                  ),
                )
              : Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.item.isDone ? Colors.grey : Colors.black,
                  ),
                ),
        ),
        Visibility(
          visible: _isHovering && !_isEditing,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note_sharp),
                iconSize: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () {
                  _toggleEditMode();
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: widget.item.isFavorite
                    ? const Icon(Icons.star, color: Colors.blue)
                    : const Icon(Icons.star_border),
                iconSize: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    widget.item.isFavorite = !widget.item.isFavorite;
                    widget.onPriorityChanged(widget.item);
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildEditControls() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 40, bottom: 8),
      child: TextField(
        onTap: () {
          if (!_descriptionTextFieldHighlighted) {
            _descriptionController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _descriptionController.text.length,
            );
            setState(() {
              _descriptionTextFieldHighlighted = true;
            });
          } else {
            setState(() {
              _descriptionTextFieldHighlighted = false;
            });
          }
        },
        cursorColor: kFlourishBlackish,
        controller: _descriptionController,
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: kFlourishBlackish,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: 'Enter description',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget buildDeadlineDescription() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _isEditing ? () => _selectDate(context) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today,
                  size: 12, color: kFlourishAdobe), // TODO different colors
              const SizedBox(width: 4),
              Text(
                _getDeadlineDescription(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kFlourishAdobe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEditSaveControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Divider(
              color: Colors.grey,
              thickness: 0.5,
              height: 0,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _cancelEditing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kFlourishLightBlackish,
                  backgroundColor: kFlourishLightBlackish.withOpacity(0.7),
                  side: const BorderSide(color: Colors.transparent),
                  fixedSize: const Size(70, 30),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kFlourishBlackish,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  foregroundColor: kFlourishAdobe,
                  backgroundColor: kFlourishAdobe.withOpacity(0.8),
                  fixedSize: const Size(70, 30),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kFlourishAliceBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDeadlineDescription() {
    final now = DateTime.now();
    final dueDate = _isEditing ? _selectedDate! : widget.item.dueDate!;
    final difference = dueDate.difference(now);
    String day;
    if (difference.inDays < 0) {
      day = '${difference.inDays.abs()} days ago';
    } else if (difference.inDays == 0) {
      day = 'Today';
    } else if (difference.inDays == 1) {
      day = 'Tomorrow';
    } else if (difference.inDays < 7) {
      day = 'In ${difference.inDays} days';
    } else {
      day = 'On ${dueDate.month}/${dueDate.day}';
    }

    if (_selectedTime == null) {
      return day;
    }

    return '$day at ${_showTimeFormatted(_selectedTime!)}';
  }

  String _showTimeFormatted(TimeOfDay time) {
    final amPm = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  void _selectDate(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(12), // Top corners rounded
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Picker
              SizedBox(
                height: 300,
                width: 300,
                child: Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: kFlourishAdobe, // Header background color
                      onPrimary: Colors.white, // Header text color
                      onSurface: Colors.black, // Text color for selectable days
                      surface:
                          Colors.grey.shade200, // Background for selected date
                    ),
                    dialogBackgroundColor:
                        Colors.white, // Dialog background color
                    datePickerTheme: const DatePickerThemeData(
                      backgroundColor: Colors.white, // Picker background
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      return CalendarDatePicker(
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        onDateChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              // Dropdown Menu for Time
              Container(
                width: 300,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: kFlourishLightBlackish),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _selectTime(context);
                      },
                      child: Text(
                        _selectedTime == null
                            ? 'Select time'
                            : _showTimeFormatted(_selectedTime!),
                        style: GoogleFonts.inter(
                          color: kFlourishBlackish,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Container(
                width: 100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: kFlourishAliceBlue,
                    backgroundColor: kFlourishAdobe,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    fixedSize: const Size(110, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      Navigator.of(context).pop();
      _selectDate(context);
    }
  }
}
