import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/scenes/scene_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/notes/draggable_note.dart';

class Notes extends StatefulWidget {
  const Notes({
    required this.onClose,
    super.key,
  });

  final VoidCallback onClose;
  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  OverlayEntry? _overlayEntry;
  bool _creatingNewNote = false;

  void _showDraggableNote() {
    _overlayEntry = OverlayEntry(
      builder: (context) => DraggableNote(
        initialTop: MediaQuery.of(context).size.height / 2 - 125,
        initialLeft: MediaQuery.of(context).size.width / 2 - 150,
        onClose: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          setState(() {
            _creatingNewNote = false;
          });
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: 400,
          height: MediaQuery.of(context).size.height - 80,
          child: Column(
            children: [
              buildTopBar(),
              ClipRRect(
                child: Container(
                  width: 400,
                  height: MediaQuery.of(context).size.height - 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xFFE0E7FF),
                        Color(0xFFF7F8FC),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Todo',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_creatingNewNote)
                        NewNoteButton(
                          onPressed: () {
                            setState(() {
                              _creatingNewNote = true;
                            });
                            _showDraggableNote();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildTopBar() {
    return Container(
      height: 40,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add),
            tooltip: 'Create a new note',
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class NewNoteButton extends StatefulWidget {
  const NewNoteButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  State<NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<NewNoteButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Expanded(
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
                    ? kFlourishNotesYellow.withOpacity(0.1)
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
                          ? kFlourishNotesYellow
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: _isHovering
                          ? kFlourishAliceBlue
                          : kFlourishNotesYellow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'New note',
                    style: GoogleFonts.inter(
                      color: kFlourishNotesYellow,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
