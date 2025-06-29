import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/notes/notes_service.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/theme_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:html' as html;
import 'draggable_note.dart';

class Notes extends StatefulWidget {
  const Notes(
      {required this.onClose, required this.onUpgradePressed, super.key});
  final VoidCallback onClose;
  final VoidCallback onUpgradePressed;
  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  final NoteService _noteService = NoteService();
  OverlayEntry? _overlayEntry;
  bool _creatingNewNote = false;
  final String _defaultFolderId = 'defaultFolder';
  List<NotePreview>? _notePreviews;

  final ValueNotifier<int> _selectedNoteIndex = ValueNotifier<int>(0);

  final _logger = getLogger('Notes Widget');
  bool isPro = false;

  int noteLimit = 5;
  int _currentNoteCount = 0;

  late final StripeSubscriptionService _stripeSubscriptionService;

  bool _isAnonymous = false;
  bool _dismissedAnonWarning = false;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _stripeSubscriptionService = StripeSubscriptionService();
    _initAuth();
    _fetchNotes();
  }

  void _initAuth() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _isAnonymous = user.isAnonymous;
      });
    }
  }

  void _showError() {
    if (!mounted) return;
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

  void _fetchNotes() async {
    try {
      final isPro = await _stripeSubscriptionService.hasProMembership();
      final activeProduct = await _stripeSubscriptionService.getActiveProduct();

      if (mounted && isPro) {
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
      if (mounted) {
        setState(() {
          _currentNoteCount = notePreviews.length;
          _notePreviews = notePreviews;
        });
      }
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
            _creatingNewNote = false;
          });
          _fetchNotes();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Stack(
      children: [
        SizedBox(
          width: 400,
          height: MediaQuery.of(context).size.height - kControlBarHeight,
          child: Column(
            children: [
              buildTopBar(themeProvider),
              Expanded(
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        themeProvider.appBackgroundGradientStart,
                        themeProvider.appBackgroundGradientEnd,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isAnonymous && !_dismissedAnonWarning)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: themeProvider.warningBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: themeProvider.warningBorderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 20,
                                    color: themeProvider.warningIconColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Notes won't be saved unless you're logged in.",
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: themeProvider.warningTextColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18,
                                      color: themeProvider.warningTextColor),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _dismissedAnonWarning = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      Text(
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.mainTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isPro && _currentNoteCount >= noteLimit)
                        buildUpgradeCallout(themeProvider),
                      Expanded(
                        child: buildNotePreviews(themeProvider),
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

  Widget buildTopBar(ThemeProvider themeProvider) {
    return Container(
      height: 50,
      color: themeProvider.appContentBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Delete selected note',
            icon: Icon(Icons.delete_outlined, color: themeProvider.iconColor),
            onPressed: () async {
              if (_notePreviews == null || _notePreviews!.isEmpty) return;
              final selectedNoteId =
                  _notePreviews![_selectedNoteIndex.value].id;
              try {
                if (_creatingNewNote) {
                  _overlayEntry?.remove();
                  _overlayEntry = null;
                  setState(() => _creatingNewNote = false);
                }
                await _noteService.deleteNote(
                  _defaultFolderId,
                  selectedNoteId,
                );
              } catch (e) {
                _logger.e('Error deleting note: $e');
                _showError();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Note deleted',
                      style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.black
                              : Colors.white)),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => _noteService.undoDelete(
                        _defaultFolderId, selectedNoteId),
                    textColor: themeProvider.primaryAppColor,
                  ),
                  duration: const Duration(seconds: 15),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                  backgroundColor: themeProvider.isDarkMode
                      ? Colors.grey[300]
                      : Colors.grey[800],
                ),
              );
            },
          ),
          VerticalDivider(
            indent: 8,
            endIndent: 8,
            color: themeProvider.dividerColor,
          ),
          if (_currentNoteCount < noteLimit || noteLimit == 0)
            IconButton(
              onPressed: () {
                setState(() => _creatingNewNote = true);
                final newNoteId = const Uuid().v4();
                _showDraggableNote(newNoteId);
              },
              icon: Icon(Icons.add, color: themeProvider.iconColor),
              tooltip: 'Create a new note',
            ),
          const SizedBox(width: 8),
          _isDownloadingPdf
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          themeProvider.iconColor),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.picture_as_pdf_outlined,
                      color: themeProvider.iconColor),
                  tooltip: 'Export selected note as PDF',
                  onPressed: () async {
                    if (_notePreviews == null || _notePreviews!.isEmpty) return;

                    final selectedNoteId =
                        _notePreviews![_selectedNoteIndex.value].id;
                    if (_creatingNewNote) {
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                      setState(() => _creatingNewNote = false);
                    }

                    setState(() => _isDownloadingPdf = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating your PDF...')),
                    );

                    try {
                      final selectedNote = await _noteService.getNoteById(
                          _defaultFolderId, selectedNoteId);

                      if (selectedNote == null) {
                        throw Exception("Selected note not found.");
                      }

                      final downloadUrl = await _noteService.exportNoteAsPdf(
                          _defaultFolderId, selectedNoteId);
                      html.window.open(downloadUrl, '_blank');
                    } catch (e) {
                      _logger.e('Error exporting note: $e');
                      _showError();
                    } finally {
                      if (mounted) {
                        setState(() => _isDownloadingPdf = false);
                      }
                    }
                  },
                ),
          if (!isPro) buildNoteUsageReport(themeProvider),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: themeProvider.iconColor),
          ),
        ],
      ),
    );
  }

  Widget buildNoteUsageReport(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.appContentBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text('Used: $_currentNoteCount / $noteLimit',
              style: TextStyle(color: themeProvider.mainTextColor)),
        ],
      ),
    );
  }

  Widget buildUpgradeCallout(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Container(
        decoration: BoxDecoration(
          color: themeProvider.warningBackgroundColor,
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
                    color: themeProvider.mainTextColor,
                  ),
                ),
                Text(
                  'Unlimited notes with Pro',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: themeProvider.secondaryTextColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryAppColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(80, 36),
                ),
                onPressed: () {
                  widget.onUpgradePressed();
                },
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    'Upgrade',
                    style: GoogleFonts.inter(
                      color: Colors.white,
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

  Widget buildNotePreviews(ThemeProvider themeProvider) {
    if (_notePreviews == null) return buildLoadingShimmer(themeProvider);
    return StreamBuilder<List<NotePreview>>(
      stream: _noteService.notePreviewsStream(_defaultFolderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _notePreviews == null) {
          return buildLoadingShimmer(themeProvider);
        } else if (snapshot.hasError) {
          _logger.e('Error fetching notes: ${snapshot.error}');
          _showError();
          return const SizedBox();
        } else if (snapshot.hasData) {
          final notes = snapshot.data!;
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _notePreviews = notes;
                });
              }
            });
          }
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
                        title: note.title,
                        preview: note.preview,
                        isSelected: selectedIndex == index,
                      ));
                },
              );
            },
          );
        } else {
          return Center(
              child: Text('No notes available',
                  style: TextStyle(color: themeProvider.mainTextColor)));
        }
      },
    );
  }

  Shimmer buildLoadingShimmer(ThemeProvider themeProvider) {
    return Shimmer.fromColors(
      baseColor:
          themeProvider.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor:
          themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: themeProvider.dividerColor,
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
                      color: themeProvider.isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 300,
                      height: 20,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
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
      {required this.title,
      required this.preview,
      required this.isSelected,
      super.key});

  final String title;
  final String preview;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected
            ? themeProvider.selectedItemBackgroundColor
            : Colors.transparent,
        border: isSelected
            ? null
            : Border(
                bottom: BorderSide(
                  color: themeProvider.dividerColor,
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
                    color: themeProvider.mainTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 14, color: themeProvider.secondaryTextColor),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
