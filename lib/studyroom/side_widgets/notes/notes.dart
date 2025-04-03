import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/notes/notes_service.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:uuid/uuid.dart';
import 'draggable_note.dart';

class Notes extends StatefulWidget {
  const Notes({required this.onClose, required this.onUpgradePressed, super.key});
  final VoidCallback onClose;
  final VoidCallback onUpgradePressed;
  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  final NoteService _noteService = NoteService();
  OverlayEntry? _overlayEntry;
  bool _creatingNewNote = false;
  // For this example, assume a default folder ID and generate a new note ID
  final String _defaultFolderId = 'defaultFolder';
  List<NotePreview>? _notePreviews;

  final ValueNotifier<int> _selectedNoteIndex = ValueNotifier<int>(0);

  final _logger = getLogger('Notes Widget');
  bool isPro = false;

  int noteLimit = 5; // the number of notes a non-pro user can have
  int _currentNoteCount = 0;

  late final StripeSubscriptionService _stripeSubscriptionService;

  @override
  void initState() {
    super.initState();
    _stripeSubscriptionService = StripeSubscriptionService();
    _fetchNotes();
  }

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

  void _fetchNotes() async {
    try {
      final isPro = await _stripeSubscriptionService.hasProMembership();
      final activeProduct = await _stripeSubscriptionService.getActiveProduct();

      if (isPro) {
        setState(() {
          if (activeProduct.noteLimit == null) {
            noteLimit = 5;
          } else {
            noteLimit = activeProduct.noteLimit!;
          }
          this.isPro = true;
        });
      }
      await _noteService.init();
      final notePreviews =
          await _noteService.fetchNotePreviews(_defaultFolderId);
      setState(() {
        _currentNoteCount = notePreviews.length;
        _notePreviews = notePreviews;
      });
    } catch (e) {
      _showError();
      _logger.e('Error fetching notes: $e');
    }
  }

  void _showDraggableNote(String noteId) {
    _logger.d('Showing draggable note with ID: $noteId');
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => DraggableNote(
        folderId: _defaultFolderId,
        noteId: noteId,
        initialTop: MediaQuery.of(context).size.height / 2 - 125,
        initialLeft: MediaQuery.of(context).size.width / 2 - 150,
        onClose: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          setState(() {
            _currentNoteCount = _notePreviews!.length;
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
        // Side panel showing a "New note" button.
        SizedBox(
          width: 400,
          height: MediaQuery.of(context).size.height - 80,
          child: Column(
            children: [
              buildTopBar(),
              Expanded(
                child: Container(
                  width: 400,
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
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isPro && _currentNoteCount >= noteLimit)
                        buildUpgradeCallout(),
                      Expanded(
                        child: buildNotePreviews(),
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
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              late final String selectedNoteId;
              if (_notePreviews == null) {
                selectedNoteId = '';
              } else {
                selectedNoteId = _notePreviews![_selectedNoteIndex.value].id;
              }
              try {
                if (_creatingNewNote) {
                  _overlayEntry?.remove();
                  _overlayEntry = null;
                  setState(() {
                    _creatingNewNote = false;
                  });
                }
                setState(() {
                  _currentNoteCount--;
                });

                await _noteService.deleteNote(
                  _defaultFolderId,
                  selectedNoteId,
                );
              } catch (e) {
                _logger.e('Error deleting note: $e');
                _showError();
                _showError();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Note deleted',
                    style: TextStyle(color: Colors.white), // Text color
                  ),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      setState(() {
                        _currentNoteCount++;
                      });
                      await _noteService.undoDelete(
                          _defaultFolderId, selectedNoteId);
                    },
                    textColor: Colors.yellow, // Change undo button color
                  ),
                  duration:
                      const Duration(seconds: 15), // Matches deletion time
                  behavior:
                      SnackBarBehavior.floating, // Makes it smaller in width
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded edges
                  ),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 50, vertical: 10), // Reduce width
                  backgroundColor: kFlourishBlackish, // Customize background
                ),
              );
            },
            tooltip: 'Delete selected note',
            icon: const Icon(Icons.delete_outlined),
          ),
          const VerticalDivider(
            indent: 8,
            endIndent: 8,
          ),
          if (_currentNoteCount < noteLimit || noteLimit == 0)
            IconButton(
              onPressed: () {
                setState(() {
                  _creatingNewNote = true;
                  _currentNoteCount++;
                });
                final newNoteId = const Uuid().v4();
                // Close any existing notes

                _showDraggableNote(newNoteId);
              },
              icon: const Icon(Icons.add),
              tooltip: 'Create a new note',
            ),
          if (!isPro) buildNoteUsageReport(),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget buildNoteUsageReport() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text('Used: $_currentNoteCount / $noteLimit'),
        ],
      ),
    );
  }

  Widget buildUpgradeCallout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Container(
        decoration: BoxDecoration(
          color: kFlourishNotesYellow.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Image.asset('assets/icons/crown.png'),
            ),
            const SizedBox(width: 10.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more notes?',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish,
                  ),
                ),
                Text(
                  'Unlimited notes with Pro',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kFlourishBlackish,
                  ),
                ),
              ],
            ),
            Spacer(),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFlourishCyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: Size(80, 36), // Set the minimum size
                ),
                onPressed: () {
                  widget.onUpgradePressed();
                },
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    'Upgrade',
                    style: GoogleFonts.inter(
                      color: kFlourishBlackish,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
  }

  Widget buildNotePreviews() {
    if (_notePreviews == null) return buildLoadingShimmer();
    return StreamBuilder<List<NotePreview>>(
      stream: _noteService.notePreviewsStream(_defaultFolderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _notePreviews == null) {
          return buildLoadingShimmer();
        } else if (snapshot.hasError) {
          _logger.e('Error fetching notes: ${snapshot.error}');
          _showError();
          return const SizedBox();
        } else if (snapshot.hasData) {
          final notes = snapshot.data!;
          _notePreviews = notes;
          debugPrint('Rebuilding notes list with ${notes.length} notes');
          return ListView.builder(
            key: ValueKey<int>(notes.length),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return ValueListenableBuilder<int>(
                valueListenable: _selectedNoteIndex,
                builder: (context, selectedIndex, child) {
                  return GestureDetector(
                      onTap: () {
                        _selectedNoteIndex.value = index;
                      },
                      onDoubleTap: () {
                        _selectedNoteIndex.value = index;
                        _showDraggableNote(note.id);
                      },
                      child: NotePreviewItem(
                        color: Colors.transparent,
                        title: note.title,
                        preview: note.preview,
                        isSelected: selectedIndex == index,
                      ));
                },
              );
            },
          );
        } else {
          return const Center(child: Text('No notes available'));
        }
      },
    );
  }

  Shimmer buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: kFlourishLightBlackish,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 200,
                      height: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 300,
                      height: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NotePreviewItem extends StatelessWidget {
  const NotePreviewItem(
      {required this.color,
      required this.title,
      required this.preview,
      required this.isSelected,
      super.key});

  final Color color;
  final String title;
  final String preview;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? kFlourishNotesYellow.withOpacity(0.3) : color,

        //only bottom border if not selected
        border: isSelected
            ? null
            : const Border(
                bottom: BorderSide(
                  color: kFlourishLightBlackish,
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kFlourishBlackish,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 14, color: kFlourishLightBlackish),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
