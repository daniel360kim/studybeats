import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  final NoteService _noteService = NoteService();

  double _top = 200;
  double _left = 100;
  double _width = 600;
  double _height = 450;
  bool _isResizing = false;
  double minimumWidth = 400;
  double minimumHeight = 300;

  // Hold the creation time; if editing an existing note, we keep its original createdAt.
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
          style: TextStyle(color: Colors.white), // Text color
        ),
        backgroundColor: Colors.red[400]!, // Set background color to red
        duration: const Duration(seconds: 3), // Show for 5 seconds
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _top = widget.initialTop;
    _left = widget.initialLeft;

    // If this note already exists, load its content.
    _loadNote();

    // Listen for changes to autosave.
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

  // Loads an existing note if available.
  void _loadNote() async {
    try {
      // Initialize the service (ensure folders exist, etc.).
      await _noteService.init();
      NoteItem? note =
          await _noteService.getNoteById(widget.folderId, widget.noteId);

      if (note != null) {
        // If the note exists, pre-fill the title and content.
        _titleController.text = note.title;
        try {
          final deltaJson = jsonDecode(note.details.content);
          _controller.document = Document.fromDelta(Delta.fromJson(deltaJson));
        } catch (e) {
          // If parsing fails, keep the default empty document.
          _logger.e('Error parsing note content: $e');
        }
        setState(() {
          _createdAt = note.createdAt;
          _updatedAt = note.updatedAt;
        });
      } else {
        // If the note doesn't exist, set the creation time to now.
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
      // Show the time in 12-hour format
      formattedDate = DateFormat.jm().format(date);
    } else if (difference < const Duration(days: 2)) {
      formattedDate = "Yesterday";
    } else if (difference.inDays < 7) {
      formattedDate = DateFormat('EEEE').format(date); // Day of the week
    } else {
      formattedDate = DateFormat('MM/dd/yyyy').format(date); // Standard format
    }

    final plainText = _controller.document.toPlainText();

    final preview = plainText.replaceAll('\n', ' ').trim();

    return '${formattedDate} - ${preview.length > 35 ? preview.substring(0, 35) : preview}';
  }

  // Autosave by updating the note in Firestore.
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

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (!_isResizing) {
            setState(() {
              _left += details.delta.dx;
              _top += details.delta.dy;
              _left = _left.clamp(0.0, screenWidth - _width);
              _top = _top.clamp(0.0, screenHeight - _height);
            });
          }
        },
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                width: _width,
                height: _height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
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
                          )),
                    _buildEditedText(),
                    _buildBottomControls(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      child: QuillSimpleToolbar(
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
                    foregroundColor: WidgetStateProperty.all(kFlourishBlackish),
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
                    foregroundColor: WidgetStateProperty.all(kFlourishBlackish),
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
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              onPanStart: (_) => _isResizing = true,
              onPanUpdate: (details) {
                setState(() {
                  _width += details.delta.dx;
                  _height += details.delta.dy;
                  _width = _width.clamp(
                      minimumWidth, MediaQuery.of(context).size.width - _left);
                  _height = _height.clamp(
                      minimumHeight, MediaQuery.of(context).size.height - _top);
                });
              },
              onPanEnd: (_) => _isResizing = false,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.drag_indicator,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
