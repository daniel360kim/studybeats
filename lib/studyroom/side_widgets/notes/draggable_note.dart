import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';

class DraggableNote extends StatefulWidget {
  const DraggableNote(
      {required this.onClose,
      required this.initialLeft,
      required this.initialTop,
      super.key});

  final VoidCallback onClose;
  final double initialTop;
  final double initialLeft;

  @override
  _DraggableNoteState createState() => _DraggableNoteState();
}

class _DraggableNoteState extends State<DraggableNote> {
  final QuillController _controller = QuillController.basic();
  final TextEditingController _titleController = TextEditingController();

  final _editorFocusNode = FocusNode();

  double _top = 200;
  double _left = 100;
  double _width = 600;
  double _height = 450;
  bool _isResizing = false;

  double minimumWidth = 400;
  double minimumHeight = 300;

  @override
  void initState() {
    super.initState();
    _top = widget.initialTop;
    _left = widget.initialLeft;
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
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
            // Move the note
            setState(() {
              _left += details.delta.dx;
              _top += details.delta.dy;

              // Keep note within screen bounds
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
                    _buildTitleEditor(),
                    _buildNoteEditor(),
                    _buildEditedText(),
                    _buildBottomControls(),
                  ],
                ),
              ),
              // Resize Handle (Bottom Right Corner)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: kFlourishYellow,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Column(
        children: [
          QuillSimpleToolbar(
              configurations: QuillSimpleToolbarConfigurations(
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
                )),
              ),
              controller: _controller),
        ],
      ),
    );
  }

  Widget _buildTitleEditor() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Expanded(
        child: TextField(
          controller: _titleController,
          style: GoogleFonts.inter(
            color: kFlourishBlackish,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: kFlourishBlackish,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Title',
            hintStyle: TextStyle(
              color: kFlourishLightBlackish,
              fontSize: 16,
            ),
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
              configurations: QuillEditorConfigurations(
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
                        null),
                  ),
                  textSelectionThemeData: TextSelectionThemeData(
                    cursorColor: kFlourishBlackish, // Sets the cursor color
                    selectionColor: kFlourishBlue
                        .withOpacity(0.4), // Sets the highlight color
                    // Sets the handles (drag points) color
                  )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditedText() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0.0, 5.0, 10.0, 7.0),
      alignment: Alignment.centerRight,
      child: Text(
        'Edited 2 days ago',
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
          IconButton(onPressed: () {}, icon: Icon(Icons.archive_outlined)),
          IconButton(onPressed: () {}, icon: Icon(Icons.delete_outline)),
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
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanStart: (_) => _isResizing = true,
              onPanUpdate: (details) {
                setState(() {
                  _width += details.delta.dx;
                  _height += details.delta.dy;

                  // Ensure minimum size
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
