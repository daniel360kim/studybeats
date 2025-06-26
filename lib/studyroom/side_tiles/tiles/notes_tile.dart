import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/notes/notes_service.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:uuid/uuid.dart';

class NotesTile extends SideWidgetTile {
  const NotesTile({required super.settings, super.key});
  NotesTile.withDefaults({super.key})
      : super(
          settings: SideWidgetSettings(
            widgetId: Uuid().v4(),
            title: 'Notes',
            description: 'Displays your notes',
            type: SideWidgetType.notes,
            size: {'width': 1, 'height': 1},
            data: {
              'theme': 'default',
            },
          ),
        );
  @override
  State<NotesTile> createState() => _NotesTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Notes',
      description: 'Displays your notes',
      type: SideWidgetType.notes,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
      },
    );
  }
}

class _NotesTileState extends State<NotesTile> {
  bool doneLoading = false;
  bool notesDoneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};

  final NoteService _noteService = NoteService();
  final String _defaultFolderId = 'defaultFolder';
  List<NotePreview>? _notePreviews;

  bool _lastPanelOpen = false;
  bool _notesInitialized = false;

  final _logger = getLogger('NotesTile');

  @override
  void initState() {
    super.initState();
    init();
    getTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPanelOpen = context.watch<SidePanelController>().isOpen;
    if (isPanelOpen && !_lastPanelOpen) {
      getTasks(); // refresh tasks when panel opens
    }
    _lastPanelOpen = isPanelOpen;
  }

  void init() async {
    try {
      data = await widget.loadSettings(SideWidgetService());
      setState(() {
        doneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
        _logger.e('Error loading notes tile $e');
      });
    }
  }

  void getTasks() async {
    try {
      if (!_notesInitialized) {
        await _noteService.init();
        _notesInitialized = true;
      }
      final notePreviews =
          await _noteService.fetchNotePreviews(_defaultFolderId);
      setState(() {
        _notePreviews = notePreviews;
        notesDoneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
        _logger.e('Error fetching notes: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!doneLoading || _notePreviews == null || !_notesInitialized) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          // Use the tile unit dimensions for consistency
          width: kTileUnitWidth,
          height: kTileUnitHeight,

          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12.0), // Match widget radius
          ),
        ),
      );
    }

    if (error) {
      showErrorContainer();
    }

    return GestureDetector(
      onTap: () {
        // Open the todo list in the toolbar
        Provider.of<StudyToolbarController>(context, listen: false)
            .openOption(NavigationOption.notes);

        // Close the side panel if it's open
        Provider.of<SidePanelController>(context, listen: false).close();
      },
      child: Container(
        width: kTileUnitWidth,
        height: kTileUnitHeight,
        decoration: BoxDecoration(
          color: kFlourishYellow,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            buildTitle(),
            buildNotes(),
          ],
        ),
      ),
    );
  }

  Widget buildTitle() {
    return Container(
      width: kTileUnitWidth,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.folder_outlined,
            color: kFlourishBlackish,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            'Notes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kFlourishBlackish,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNotes() {
    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight - 50, // Adjust for title height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.0),
          bottomRight: Radius.circular(12.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: (_notePreviews == null || _notePreviews!.isEmpty)
          ? Center(
              child: Text(
                'No notes available',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _notePreviews!.length,
              itemBuilder: (context, index) {
                final note = _notePreviews![index];
                return Column(
                  children: [
                    ListTile(
                      title: Text(
                        note.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kFlourishBlackish,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      onTap: null,
                    ),
                    if (index < _notePreviews!.length - 1)
                      Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                        height: 1,
                      ),
                  ],
                );
              },
            ),
    );
  }
}
