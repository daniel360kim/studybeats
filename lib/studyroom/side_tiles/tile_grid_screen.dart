import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/calendar_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/clock_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/current_song_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/date_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/digital_clock_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/notes_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/study_graphs.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/study_statistics_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/todo_tile.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/weather_tile.dart';
import 'tile_screen_controller.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

// All available side widget tiles in the library.
List<SideWidgetTile> sideWidgetTileLibrary = [
  ClockTile.withDefaults(),
  CalendarTile.withDefaults(),
  CurrentSongTile.withDefaults(),
  DateTile.withDefaults(),
  TodoTile.withDefaults(),
  StudyStatisticsTile.withDefaults(),
  DigitalClockTile.withDefaults(),
  WeatherTile.withDefaults(isPreview: true),
  NotesTile.withDefaults(),
  //StudyGraphsTile.withDefaults(),
  // Add more tiles as needed
];

const kSideWidgetAnimationDuration = Duration(milliseconds: 300);

/// A sliding panel that displays draggable and reorderable widget tiles,
/// such as clocks, weather, or productivity modules.
class SideWidgetScreen extends StatefulWidget {
  const SideWidgetScreen({super.key});

  @override
  State<SideWidgetScreen> createState() => _SideWidgetScreenState();
}

class _SideWidgetScreenState extends State<SideWidgetScreen> {
  List<SideWidgetSettings> _tileSettings = [];
  final SideWidgetService _widgetService = SideWidgetService();
  bool _initialized = false;

  bool _isDeleting = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _initializeTiles();
  }

  Future<void> _initializeTiles() async {
    await _widgetService.init();
    final tiles = await _widgetService.loadOrderedWidgets();
    final updatedTiles = tiles.map(applyDefaults).toList();
    setState(() {
      _tileSettings = updatedTiles;
      _initialized = true;
    });
  }

  /// Ensures settings have required default fields and syncs if new fields are added.
  SideWidgetSettings applyDefaults(SideWidgetSettings settings) {
    final defaultData = <String, dynamic>{
      'theme': 'default',
      'timezone': 'UTC',
    };

    bool updated = false;
    final updatedData = Map<String, dynamic>.from(settings.data);

    for (final entry in defaultData.entries) {
      if (!updatedData.containsKey(entry.key)) {
        updatedData[entry.key] = entry.value;
        updated = true;
      }
    }

    if (updated) {
      final updatedSettings = SideWidgetSettings(
        widgetId: settings.widgetId,
        type: settings.type,
        size: settings.size,
        data: updatedData,
      );
      _widgetService.saveWidgetSettings(updatedSettings);
      return updatedSettings;
    }

    return settings;
  }

  SideWidgetTile buildTile(SideWidgetSettings settings) {
    switch (settings.type) {
      case SideWidgetType.clock:
        return ClockTile(settings: settings);
      case SideWidgetType.calendar:
        return CalendarTile(settings: settings);
      case SideWidgetType.currentSong:
        return CurrentSongTile(settings: settings);
      case SideWidgetType.date:
        return DateTile(settings: settings);
      case SideWidgetType.todo:
        return TodoTile(settings: settings);
      case SideWidgetType.studyStatistics:
        return StudyStatisticsTile(settings: settings);
      case SideWidgetType.digitalClock:
        return DigitalClockTile(settings: settings);
      case SideWidgetType.weather:
        return WeatherTile(isPreview: false, settings: settings);
      case SideWidgetType.notes:
        return NotesTile(settings: settings);
      case SideWidgetType.studyGraph:
        return StudyGraphsTile(settings: settings); // Replace with actual tile
    }
  }

  void _showAddWidgetBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount =
                (width / 180).floor().clamp(1, 4); // adaptive tile count
            final tileSize = width / crossAxisCount - 24;

            return Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 500),
              child: GridView.builder(
                itemCount: sideWidgetTileLibrary.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final tile = sideWidgetTileLibrary[index];
                  return Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: tileSize * 0.6,
                            height: tileSize * 0.6,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: tile,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                try {
                                  final newSettings =
                                      await _widgetService.createAndAddWidget(
                                    type: tile.settings.type,
                                    size: tile.settings.size,
                                    data: tile.settings.data,
                                  );
                                  setState(() {
                                    _tileSettings.add(newSettings);
                                  });
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error adding widget: $e')),
                                  );
                                }
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tile.settings.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tile.settings.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      /*
                      ElevatedButton(
                          onPressed: () async {
                            final injector =
                                TestDataInjector(StudySessionService());
                            await injector.injectTestData();
                          },
                          child: const Text('Inject Test Data')),
                          */
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = context.watch<SidePanelController>().isOpen;
    const panelWidth = 358.0;
    const tileSize = 160.0;

    return AnimatedPositioned(
      duration: kSideWidgetAnimationDuration,
      curve: Curves.easeInOut,
      top: 0,
      right: visible ? 0 : -panelWidth,
      width: panelWidth,
      child: TapRegion(
        onTapOutside: (event) {
          final sidePanelController = context.read<SidePanelController>();
          if (sidePanelController.isOpen) {
            sidePanelController.close();
          }
          if (_isAdding) {
            setState(() {
              _isAdding = false;
            });
          }
          if (_isDeleting) {
            setState(() {
              _isDeleting = false;
            });
          }
        },
        consumeOutsideTaps: false,
        // Add this line to exclude the DateTimeWidget from triggering onTapOutside

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastLinearToSlowEaseIn,
          constraints: const BoxConstraints(minHeight: 0),
          onEnd: () {},
          child: SizedBox(
            height: MediaQuery.of(context).size.height - kControlBarHeight,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3,
                        sigmaY: 2,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(25)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 16,
                              ),
                              ReorderableWrap(
                                spacing: 12,
                                runSpacing: 12,

                                needsLongPressDraggable: false,
                                reorderAnimationDuration:
                                    const Duration(milliseconds: 500),

                                // Handles drag-and-drop reorder logic
                                onReorder: (oldIndex, newIndex) async {
                                  setState(() {
                                    final item =
                                        _tileSettings.removeAt(oldIndex);
                                    _tileSettings.insert(newIndex, item);
                                  });

                                  final ids = _tileSettings
                                      .map((s) => s.widgetId)
                                      .toList();
                                  // Save the new order as a field in the __meta__ document inside the sideWidgets collection
                                  await _widgetService.updateWidgetOrder(ids);
                                },

                                // Build each tile with consistent sizing and key
                                children:
                                    _tileSettings.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final settings = entry.value;
                                  final tile = buildTile(settings);

                                  return ReorderableDelayedDragStartListener(
                                    index: index,
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          key: ValueKey(settings.widgetId),
                                          width: tileSize,
                                          height: tileSize,
                                          child: tile,
                                        ),
                                        if (_isDeleting)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () async {
                                                setState(() {
                                                  _tileSettings.removeAt(index);
                                                });
                                                try {
                                                  await _widgetService
                                                      .deleteWidgetFromOrder(
                                                          settings.widgetId);
                                                } catch (e) {
                                                  // Handle any errors that occur during deletion
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Error deleting widget: $e'),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: MouseRegion(
                                                cursor:
                                                    SystemMouseCursors.click,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.red,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.red
                                                            .withOpacity(0.5),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  buildControlButtons(),
                  SizedBox(
                    height: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2C2C2C),
            border:
                Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
          ),
          child: Center(
            child: GestureDetector(
              onTap: () {
                _showAddWidgetBottomSheet();

                setState(() {
                  _isAdding = !_isAdding;
                });
              },
              child: Icon(
                Icons.add,
                size: 16,
                color: !_isDeleting ? Colors.white : const Color(0xFFCCCCCC),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isDeleting ? Colors.red : const Color(0xFF2C2C2C),
            border:
                Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
          ),
          child: Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isDeleting = !_isDeleting;
                });
              },
              child: Icon(
                Icons.delete,
                size: 16,
                color: _isDeleting ? Colors.white : const Color(0xFFCCCCCC),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
