import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/studyroom/audio/display_track_info.dart';
import 'package:studybeats/studyroom/audio/display_track_notifier.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class CurrentSongTile extends SideWidgetTile {
  const CurrentSongTile({required super.settings, super.key});
  CurrentSongTile.withDefaults({super.key})
      : super(
            settings: SideWidgetSettings(
          type: SideWidgetType.currentSong,
          title: 'Current Song',
          description: 'Displays the currently playing song',
          size: {
            'width': 1,
            'height': 1,
          },
          // Generate a unique widget ID
          widgetId: Uuid().v4(),

          data: {
            'theme': 'default',
          },
        ));

  @override
  State<CurrentSongTile> createState() => _CurrentSongTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Current Song',
      description: 'Displays the currently playing song',
      type: SideWidgetType.currentSong,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
      },
    );
  }
}

class _CurrentSongTileState extends State<CurrentSongTile>
    with WidgetsBindingObserver {
  bool doneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    initSettings();
  }

  void initSettings() async {
    try {
      data = await widget.loadSettings(SideWidgetService());
      setState(() {
        doneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!doneLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: kTileUnitWidth,
          height: kTileUnitHeight,
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12.0), // Match widget radius
          ),
        ),
      );
    }

    if (error) showErrorContainer();

    final DisplayTrackInfo? trackInfo =
        context.watch<DisplayTrackNotifier>().track;

    // Here you would typically return a widget that displays the current song
    // For example, a Text widget or a custom widget that shows the song details
    return trackInfo != null
        ? Stack(
            children: [
              // Album art as background
              if (trackInfo.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.network(
                    trackInfo.imageUrl!
                        .replaceAll('100x100bb.jpg', '300x300bb.jpg'),
                    width: kTileUnitWidth,
                    height: kTileUnitHeight,
                    fit: BoxFit.cover,
                  ),
                ),

              // Blur layer
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                  child: Container(
                    width: kTileUnitWidth,
                    height: kTileUnitHeight,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),

              // Top-left Now Playing label
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.music_note, size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Gradient + song info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(12.0)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackInfo.trackName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        trackInfo.artistName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (trackInfo.albumName != null)
                        Text(
                          trackInfo.albumName!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Container(
            width: kTileUnitWidth,
            height: kTileUnitHeight,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'No song currently playing',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
  }
}
