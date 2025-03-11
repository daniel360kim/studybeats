import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoItemTile extends StatefulWidget {
  const TodoItemTile({
    required this.item,
    required this.isEditing,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onItemMarkedAsDone,
    required this.onItemDetailsChanged,
    required this.onItemDateTimeChanged,
    required this.onItemDelete,
    super.key,
  });

  final TodoItem item;
  final bool isEditing;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final VoidCallback onItemMarkedAsDone;
  final ValueChanged<TodoItem> onItemDetailsChanged;
  final ValueChanged<TodoItem> onItemDateTimeChanged;
  final VoidCallback onItemDelete;

  @override
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile> {
  bool _isHovering = false;
  bool _isDateButtonHovering = false;
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

    _selectedDate = widget.item.dueDate;
    _selectedTime = widget.item.dueTime;
  }

  @override
  void didUpdateWidget(covariant TodoItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the item has changed externally, update our controllers.
    if (oldWidget.item.title != widget.item.title) {
      _titleController.text = widget.item.title;
    }
    if (oldWidget.item.description != widget.item.description) {
      _descriptionController.text = widget.item.description ?? '';
    }
    if (oldWidget.item.dueDate != widget.item.dueDate) {
      _selectedDate = widget.item.dueDate;
    }
    if (oldWidget.item.dueTime != widget.item.dueTime) {
      _selectedTime = widget.item.dueTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    // Update the item with the latest edits.
    widget.item.title = _titleController.text;
    widget.item.description = _descriptionController.text;
    widget.item.dueDate = _selectedDate;
    widget.item.dueTime = _selectedTime;
    widget.onItemDetailsChanged(widget.item);
    // Notify parent to turn editing off.
    widget.onEditEnd();
  }

  void _cancelEditing() {
    // Reset controllers to the original values.
    _titleController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _selectedDate = widget.item.dueDate;
    _selectedTime = widget.item.dueTime;
    widget.onEditEnd();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isEditing) {
          widget.onEditStart();
        }
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
              color: _isHovering || widget.isEditing
                  ? kFlourishLightBlackish.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Column(
              children: [
                buildTitle(),
                if (widget.item.description != null &&
                    widget.item.description!.isNotEmpty &&
                    !widget.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                if (widget.isEditing) buildEditControls(),
                if (widget.item.dueDate != null || widget.isEditing)
                  buildDeadlineDescription(),
                if (widget.isEditing) buildEditSaveControls(),
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
        Expanded(
          child: widget.isEditing
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
          visible: _isHovering && !widget.isEditing,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note_sharp),
                iconSize: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: widget.onEditStart,
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
                  });
                  widget.onItemDetailsChanged(widget.item);
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
          onTap: widget.isEditing ? () => _selectDate(context) : null,
          child: MouseRegion(
            cursor: widget.isEditing
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _isDateButtonHovering && widget.isEditing
                    ? kFlourishAdobe.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today,
                      size: 12, color: kFlourishAdobe),
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
            onEnter: (_) => setState(() => _isDateButtonHovering = true),
            onExit: (_) => setState(() => _isDateButtonHovering = false),
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outlined),
                iconSize: 25,
                onPressed: () {
                  widget.onItemDelete();
                },
              ),
              const Spacer(),
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
    if (_selectedDate == null) {
      return 'Add date';
    }
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final fullDueDate =
        widget.isEditing ? _selectedDate! : widget.item.dueDate!;
    final dueDate =
        DateTime(fullDueDate.year, fullDueDate.month, fullDueDate.day);
    final differenceInDays = dueDate.difference(nowDate).inDays;
    String day;
    if (differenceInDays < 0) {
      final absDays = differenceInDays.abs();
      day = '$absDays ${absDays == 1 ? "day" : "days"} ago';
    } else if (differenceInDays == 0) {
      day = 'Today';
    } else if (differenceInDays == 1) {
      day = 'Tomorrow';
    } else if (differenceInDays < 7) {
      day = 'In $differenceInDays days';
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
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 300,
                width: 300,
                child: Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: kFlourishAdobe,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                      surface: Colors.grey.shade200,
                    ),
                    dialogBackgroundColor: Colors.white,
                    datePickerTheme: const DatePickerThemeData(
                      backgroundColor: Colors.white,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: ElevatedButton(
                      onPressed: () {
                        _selectedDate = widget.item.dueDate;
                        _selectedTime = widget.item.dueTime;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: kFlourishBlackish,
                        backgroundColor: kFlourishLightBlackish,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        fixedSize: const Size(110, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                  Container(
                    width: 100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: kFlourishAliceBlue,
                        backgroundColor: kFlourishAdobe,
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
              primary: kFlourishBlackish,
              onPrimary: Colors.white,
              onSurface: kFlourishBlackish,
            ),
            dialogBackgroundColor: Colors.white,
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: kFlourishBlackish,
              selectionColor: Colors.grey.shade300,
              selectionHandleColor: kFlourishBlackish,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: kFlourishBlackish,
              dayPeriodTextColor: kFlourishBlackish,
              dayPeriodColor: kFlourishAdobe,
              hourMinuteColor: Colors.grey.shade200,
              dialBackgroundColor: Colors.white,
              dialHandColor: kFlourishAdobe,
              dialTextColor: kFlourishBlackish,
              entryModeIconColor: kFlourishBlackish,
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
