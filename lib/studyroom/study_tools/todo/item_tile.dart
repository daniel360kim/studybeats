import 'package:studybeats/api/todo/todo_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/theme_provider.dart';

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
    widget.item.title = _titleController.text;
    widget.item.description = _descriptionController.text;
    widget.item.dueDate = _selectedDate;
    widget.item.dueTime = _selectedTime;
    widget.onItemDetailsChanged(widget.item);
    widget.onEditEnd();
  }

  void _cancelEditing() {
    _titleController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _selectedDate = widget.item.dueDate;
    _selectedTime = widget.item.dueTime;
    widget.onEditEnd();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
                  ? themeProvider.primaryAppColor.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Column(
              children: [
                buildTitle(themeProvider),
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
                          color: themeProvider.secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                if (widget.isEditing) buildEditControls(themeProvider),
                if (widget.item.dueDate != null || widget.isEditing)
                  buildDeadlineDescription(themeProvider),
                if (widget.isEditing) buildEditSaveControls(themeProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTitle(ThemeProvider themeProvider) {
    return Row(
      children: [
        Checkbox(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          value: widget.item.isDone,
          activeColor: themeProvider.primaryAppColor,
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
                  cursorColor: themeProvider.primaryAppColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter title',
                    hintStyle:
                        TextStyle(color: themeProvider.secondaryTextColor),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.mainTextColor,
                  ),
                )
              : Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.item.isDone
                        ? themeProvider.secondaryTextColor
                        : themeProvider.mainTextColor,
                  ),
                ),
        ),
        Visibility(
          visible: _isHovering && !widget.isEditing,
          child: Row(
            children: [
              IconButton(
                icon:
                    Icon(Icons.edit_note_sharp, color: themeProvider.iconColor),
                iconSize: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: widget.onEditStart,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: widget.item.isFavorite
                    ? Icon(Icons.star, color: themeProvider.primaryAppColor)
                    : Icon(Icons.star_border, color: themeProvider.iconColor),
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

  Widget buildEditControls(ThemeProvider themeProvider) {
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
        cursorColor: themeProvider.primaryAppColor,
        controller: _descriptionController,
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: themeProvider.mainTextColor,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: 'Enter description',
          hintStyle: TextStyle(color: themeProvider.secondaryTextColor),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget buildDeadlineDescription(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: widget.isEditing
              ? () => _selectDate(context, themeProvider)
              : null,
          child: MouseRegion(
            cursor: widget.isEditing
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _isDateButtonHovering && widget.isEditing
                    ? themeProvider.primaryAppColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: themeProvider.primaryAppColor),
                  const SizedBox(width: 4),
                  Text(
                    _getDeadlineDescription(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.primaryAppColor,
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

  Widget buildEditSaveControls(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Divider(
              color: themeProvider.dividerColor,
              thickness: 0.5,
              height: 0,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon:
                    Icon(Icons.delete_outlined, color: themeProvider.iconColor),
                iconSize: 25,
                onPressed: () {
                  widget.onItemDelete();
                },
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _cancelEditing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: themeProvider.secondaryTextColor,
                  backgroundColor: themeProvider.dividerColor,
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
                    color: themeProvider.mainTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: themeProvider.primaryAppColor,
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
                    color: Colors.white,
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

  void _selectDate(BuildContext context, ThemeProvider themeProvider) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: themeProvider.popupBackgroundColor,
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
                  data: themeProvider.isDarkMode
                      ? ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: themeProvider.primaryAppColor,
                            onPrimary: Colors.white,
                            surface: themeProvider.popupBackgroundColor,
                            onSurface: themeProvider.mainTextColor,
                          ),
                          dialogBackgroundColor:
                              themeProvider.popupBackgroundColor,
                        )
                      : ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: themeProvider.primaryAppColor,
                            onPrimary: Colors.white,
                            onSurface: themeProvider.mainTextColor,
                          ),
                          dialogBackgroundColor:
                              themeProvider.popupBackgroundColor,
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
                    top: BorderSide(color: themeProvider.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: themeProvider.secondaryTextColor),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _selectTime(context, themeProvider);
                      },
                      child: Text(
                        _selectedTime == null
                            ? 'Select time'
                            : _showTimeFormatted(_selectedTime!),
                        style: GoogleFonts.inter(
                          color: themeProvider.mainTextColor,
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
                        foregroundColor: themeProvider.mainTextColor,
                        backgroundColor: themeProvider.dividerColor,
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
                        foregroundColor: Colors.white,
                        backgroundColor: themeProvider.primaryAppColor,
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
      Navigator.of(context).pop();
      _selectDate(context, themeProvider);
    }
  }
}
