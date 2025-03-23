import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/notes/notes_service.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';

class DraggableNote extends StatefulWidget {
  const DraggableNote({
    required this.onClose,
    required this.initialLeft,
    required this.initialTop,
    required this.folderId,
    required this.noteId,
    super.key,
  });

  final VoidCallback onClose;
  final double initialTop;
  final double initialLeft;
  final String folderId;
  final String noteId;

  @override
  _DraggableNoteState createState() => _DraggableNoteState();
}

class _DraggableNoteState extends State<DraggableNote> {
  final QuillController _controller = QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  late final NoteService _noteService;

  double _top = 200;
  double _left = 100;
  double _width = 600;
  double _height = 450;

  // Define minimum sizes and constants for border thickness and corner size.
  final double minimumWidth = 400;
  final double minimumHeight = 300;
  static const double borderThickness = 8.0;
  static const double cornerSize = 16.0;

  // Hold note creation and update times.
  late DateTime _createdAt;
  late DateTime _updatedAt;
  String _editedTimeText = '';

  bool _loadingNote = true;
  final _logger = getLogger('DraggableNote');

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Something went wrong',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[400]!,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _top = widget.initialTop;
    _left = widget.initialLeft;

    _noteService = NoteService();
    _loadNote();

    _controller.addListener(() {
      _autosaveNote();
    });
    _titleController.addListener(() {
      _autosaveNote();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _noteService.cancelPendingSave();
    super.dispose();
  }

  void _loadNote() async {
    try {
      await _noteService.init();
      NoteItem? note =
          await _noteService.getNoteById(widget.folderId, widget.noteId);

      if (note != null) {
        _titleController.text = note.title;
        try {
          final deltaJson = jsonDecode(note.details.content);
          _controller.document = Document.fromDelta(Delta.fromJson(deltaJson));
        } catch (e) {
          _logger.e('Error parsing note content: $e');
        }
        setState(() {
          _createdAt = note.createdAt;
          _updatedAt = note.updatedAt;
        });
      } else {
        setState(() {
          _createdAt = DateTime.now();
          _updatedAt = DateTime.now();
        });
      }
      _updateEditedTimeText();

      setState(() {
        _loadingNote = false;
      });
    } catch (e) {
      _logger.e('Error initializing NoteService: $e');
      _showError();
      return;
    }
  }

  String _getPreview() {
    final now = DateTime.now();
    final date = _updatedAt.toLocal();
    final difference = now.difference(date);

    String formattedDate;
    if (difference < const Duration(days: 1)) {
      formattedDate = DateFormat.jm().format(date);
    } else if (difference < const Duration(days: 2)) {
      formattedDate = "Yesterday";
    } else if (difference.inDays < 7) {
      formattedDate = DateFormat('EEEE').format(date);
    } else {
      formattedDate = DateFormat('MM/dd/yyyy').format(date);
    }

    final plainText = _controller.document.toPlainText();
    final preview = plainText.replaceAll('\n', ' ').trim();
    return '$formattedDate - ${preview.length > 35 ? preview.substring(0, 35) : preview}';
  }

  void _autosaveNote() async {
    String title = _titleController.text;
    final delta = _controller.document.toDelta().toJson();
    final contentJson = jsonEncode(delta);
    final preview = _getPreview();

    if (title.isEmpty) title = 'Untitled Note';

    final note = NoteItem(
      id: widget.noteId,
      title: title,
      preview: preview,
      details: NoteDetails(content: contentJson),
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _updatedAt = note.updatedAt;
    });
    _updateEditedTimeText();
    try {
      await _noteService.saveNote(widget.folderId, note);
    } catch (e) {
      _logger.e('Error saving note: $e');
      _showError();
      return;
    }
  }

  /// Helper to build an edge resizer. Only one of [width] or [height] should be provided.
  Widget _buildEdgeResizer({
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? width,
    double? height,
    required SystemMouseCursor cursor,
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: onPanUpdate,
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  /// Helper to build a corner resizer.
  Widget _buildCornerResizer({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required SystemMouseCursor cursor,
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      width: cornerSize,
      height: cornerSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: onPanUpdate,
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: _top,
      left: _left,
      child: Stack(
        children: [
          // Main draggable note area.
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _left += details.delta.dx;
                _top += details.delta.dy;
                _left = _left.clamp(0.0, screenWidth - _width);
                _top = _top.clamp(0.0, screenHeight - _height);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: _width,
                  height: _height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToolbar(_width),
                      !_loadingNote
                          ? _buildTitleEditor()
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      !_loadingNote
                          ? _buildNoteEditor()
                          : Expanded(
                              child: Column(
                                children: List.generate(
                                  _height ~/ 80,
                                  (index) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(
                                        height: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      _buildEditedText(),
                      _buildBottomControls(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Edge Resizers
          _buildEdgeResizer(
            top: 0,
            left: 0,
            right: 0,
            height: borderThickness,
            cursor: SystemMouseCursors.resizeUpDown,
            onPanUpdate: (details) {
              setState(() {
                double newTop = _top + details.delta.dy;
                double newHeight = _height - details.delta.dy;
                if (newHeight >= minimumHeight && newTop >= 0) {
                  _top = newTop;
                  _height = newHeight;
                }
              });
            },
          ),
          _buildEdgeResizer(
            bottom: 0,
            left: 0,
            right: 0,
            height: borderThickness,
            cursor: SystemMouseCursors.resizeUpDown,
            onPanUpdate: (details) {
              setState(() {
                double newHeight = _height + details.delta.dy;
                if (newHeight >= minimumHeight &&
                    _top + newHeight <= screenHeight) {
                  _height = newHeight;
                }
              });
            },
          ),
          _buildEdgeResizer(
            left: 0,
            top: 0,
            bottom: 0,
            width: borderThickness,
            cursor: SystemMouseCursors.resizeLeftRight,
            onPanUpdate: (details) {
              setState(() {
                double newLeft = _left + details.delta.dx;
                double newWidth = _width - details.delta.dx;
                if (newWidth >= minimumWidth && newLeft >= 0) {
                  _left = newLeft;
                  _width = newWidth;
                }
              });
            },
          ),
          _buildEdgeResizer(
            right: 0,
            top: 0,
            bottom: 0,
            width: borderThickness,
            cursor: SystemMouseCursors.resizeLeftRight,
            onPanUpdate: (details) {
              setState(() {
                double newWidth = _width + details.delta.dx;
                if (newWidth >= minimumWidth &&
                    _left + newWidth <= screenWidth) {
                  _width = newWidth;
                }
              });
            },
          ),
          // Corner Resizers
          _buildCornerResizer(
            top: 0,
            left: 0,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            onPanUpdate: (details) {
              setState(() {
                double newLeft = _left + details.delta.dx;
                double newTop = _top + details.delta.dy;
                double newWidth = _width - details.delta.dx;
                double newHeight = _height - details.delta.dy;
                if (newWidth >= minimumWidth &&
                    newHeight >= minimumHeight &&
                    newLeft >= 0 &&
                    newTop >= 0) {
                  _left = newLeft;
                  _top = newTop;
                  _width = newWidth;
                  _height = newHeight;
                }
              });
            },
          ),
          _buildCornerResizer(
            top: 0,
            right: 0,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            onPanUpdate: (details) {
              setState(() {
                double newTop = _top + details.delta.dy;
                double newWidth = _width + details.delta.dx;
                double newHeight = _height - details.delta.dy;
                if (newWidth >= minimumWidth &&
                    newHeight >= minimumHeight &&
                    newTop >= 0 &&
                    _left + newWidth <= screenWidth) {
                  _top = newTop;
                  _width = newWidth;
                  _height = newHeight;
                }
              });
            },
          ),
          _buildCornerResizer(
            bottom: 0,
            left: 0,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            onPanUpdate: (details) {
              setState(() {
                double newLeft = _left + details.delta.dx;
                double newWidth = _width - details.delta.dx;
                double newHeight = _height + details.delta.dy;
                if (newWidth >= minimumWidth &&
                    newHeight >= minimumHeight &&
                    newLeft >= 0 &&
                    _top + newHeight <= screenHeight) {
                  _left = newLeft;
                  _width = newWidth;
                  _height = newHeight;
                }
              });
            },
          ),
          _buildCornerResizer(
            bottom: 0,
            right: 0,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            onPanUpdate: (details) {
              setState(() {
                double newWidth = _width + details.delta.dx;
                double newHeight = _height + details.delta.dy;
                if (newWidth >= minimumWidth &&
                    newHeight >= minimumHeight &&
                    _left + newWidth <= screenWidth &&
                    _top + newHeight <= screenHeight) {
                  _width = newWidth;
                  _height = newHeight;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: kFlourishYellow,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                iconSize: 15,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: kFlourishBlackish,
                ),
              ),
            ),
          ),
          QuillSimpleToolbar(
            config: QuillSimpleToolbarConfig(
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showListNumbers: true,
              showListBullets: true,
              showUndo: true,
              showRedo: true,
              showClearFormat: true,
              showFontFamily: false,
              showFontSize: false,
              showAlignmentButtons: false,
              showHeaderStyle: false,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showClipboardCut: false,
              showClipboardCopy: false,
              showClipboardPaste: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                base: QuillToolbarBaseButtonOptions(
                  iconTheme: QuillIconTheme(
                    iconButtonUnselectedData: IconButtonData(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(Colors.transparent),
                        foregroundColor:
                            WidgetStateProperty.all(kFlourishBlackish),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    iconButtonSelectedData: IconButtonData(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          kFlourishBlackish.withOpacity(0.2),
                        ),
                        foregroundColor:
                            WidgetStateProperty.all(kFlourishBlackish),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  afterButtonPressed: () {
                    _editorFocusNode.requestFocus();
                  },
                ),
              ),
            ),
            controller: _controller,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleEditor() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: _titleController,
        style: GoogleFonts.inter(
          color: kFlourishBlackish,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: kFlourishBlackish,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Title',
          hintStyle: TextStyle(
            color: kFlourishLightBlackish,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteEditor() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: DefaultTextStyle(
            style: GoogleFonts.inter(
              color: kFlourishBlackish,
              fontSize: 10,
            ),
            child: QuillEditor.basic(
              focusNode: _editorFocusNode,
              controller: _controller,
              config: QuillEditorConfig(
                placeholder: 'Start writing...',
                customStyles: DefaultStyles(
                  placeHolder: DefaultTextBlockStyle(
                    GoogleFonts.roboto(
                      fontSize: 16,
                      color: kFlourishLightBlackish,
                    ),
                    HorizontalSpacing.zero,
                    VerticalSpacing.zero,
                    VerticalSpacing.zero,
                    null,
                  ),
                ),
                textSelectionThemeData: TextSelectionThemeData(
                  cursorColor: kFlourishBlackish,
                  selectionColor: kFlourishBlue.withOpacity(0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateEditedTimeText() {
    final now = DateTime.now();
    final date = _updatedAt.toLocal();
    final difference = now.difference(date);

    String editedTimeText = '';
    if (difference < const Duration(minutes: 1)) {
      editedTimeText = 'just now';
    } else if (difference < const Duration(hours: 1)) {
      editedTimeText = '${difference.inMinutes} minutes ago';
    } else if (difference < const Duration(days: 1)) {
      editedTimeText = '${difference.inHours} hours ago';
    } else {
      editedTimeText = 'on ${DateFormat('MM/dd/yyyy').format(date)}';
    }

    setState(() {
      _editedTimeText = editedTimeText;
    });
  }

  Widget _buildEditedText() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0.0, 5.0, 10.0, 7.0),
      alignment: Alignment.centerRight,
      child: Text(
        'Edited $_editedTimeText',
        style: GoogleFonts.inter(
          color: kFlourishLightBlackish,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kFlourishYellow.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          OutlinedButton(
            onPressed: widget.onClose,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.transparent),
              foregroundColor: kFlourishBlackish,
            ),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kFlourishBlackish,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
