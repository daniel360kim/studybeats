import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SongQueue extends StatefulWidget {
  const SongQueue({
    super.key,
    required this.currentSong,
    required this.queue,
    required this.songOrder,
    required this.onSongSelected,
  });

  final SongMetadata? currentSong;
  final List<SongMetadata>? queue;
  final List<SongMetadata>? songOrder;
  final ValueChanged<int> onSongSelected;

  @override
  State<SongQueue> createState() => _SongQueueState();
}

class _SongQueueState extends State<SongQueue> {
  final borderRadius = const BorderRadius.only(
    topLeft: Radius.circular(40.0),
    topRight: Radius.circular(40.0),
  );

  int getSongOrderIndex(int queueIndex) {
    if (queueIndex < 0 || queueIndex >= (widget.queue?.length ?? 0)) {
      return -1;
    }

    final songInQueue = widget.queue![queueIndex];
    return widget.songOrder?.indexWhere((song) => song.id == songInQueue.id) ??
        -1;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.queue == null || widget.songOrder == null;
    final isQueueEmpty = widget.queue == null || widget.queue!.isEmpty;
    final isSongOrderEmpty =
        widget.songOrder == null || widget.songOrder!.isEmpty;

    return SizedBox(
      width: 500,
      height: MediaQuery.of(context).size.height - 80 * 2,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20.0, 30.0, 20.0, 0.0),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(170, 170, 170, 0.7),
              borderRadius: borderRadius,
            ),
            child: Column(
              children: [
                buildHeader(),
                const SizedBox(height: 20),
                buildCurrentSong(),
                const SizedBox(height: 10),
                isLoading
                    ? _buildLoadingIndicator()
                    : isQueueEmpty && isSongOrderEmpty
                        ? _buildEmptyState()
                        : buildQueue(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        'Queue',
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildCurrentSong() {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Playing Now',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          QueueSongItem(
            song: widget.currentSong,
            onPressed: () {
              if (widget.currentSong?.id != null) {
                final queueIndex = widget.queue?.indexWhere(
                        (song) => song.id == widget.currentSong!.id) ??
                    -1;
                final songOrderIndex = getSongOrderIndex(queueIndex);
                widget.onSongSelected(songOrderIndex);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget buildQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Up Next',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.of(context).size.height - 80 * 2 - 289,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.queue?.length ?? 0,
            itemBuilder: (context, index) {
              return QueueSongItem(
                song: widget.queue?[index],
                onPressed: () {
                  final songOrderIndex = getSongOrderIndex(index);
                  widget.onSongSelected(songOrderIndex);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No songs available',
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class QueueSongItem extends StatefulWidget {
  const QueueSongItem({required this.song, required this.onPressed, super.key});

  final SongMetadata? song;
  final VoidCallback onPressed;

  @override
  State<QueueSongItem> createState() => _QueueSongItemState();
}

class _QueueSongItemState extends State<QueueSongItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          _isHovering = true;
        });
      },
      onExit: (event) {
        setState(() {
          _isHovering = false;
        });
      },
      child: GestureDetector(
        onDoubleTap: () => widget.onPressed(),
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color:
                _isHovering ? Colors.grey.withOpacity(0.5) : Colors.transparent,
          ),
          child: widget.song == null
              ? _buildShimmerPlaceholder()
              : Row(
                  children: [
                    PlayButton(
                      isHovering: _isHovering,
                      onPressed: widget.onPressed,
                      thumbnailUrl: widget.song!.artworkUrl100,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song!.trackName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          widget.song!.artistName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _isHovering
                        ? Theme(
                            data: ThemeData(
                              popupMenuTheme: const PopupMenuThemeData(
                                  elevation: 5,
                                  color: Color.fromRGBO(57, 57, 57, 1)),
                            ),
                            child: PopupMenuButton(
                              itemBuilder: (context) {
                                return [
                                  PopupMenuItem(
                                    onTap: () {
                                      final link = widget.song?.youtubeLink;
                                      if (link != null) {
                                        // Copy link to clipboard
                                        Clipboard.setData(
                                            ClipboardData(text: link));
                                        // Show snackbar
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Link copied to clipboard'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const PopupMenuDetails(
                                      icon: Icons.copy,
                                      text: 'Copy link',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () {
                                      final link = widget.song?.youtubeLink;
                                      if (link != null) {
                                        // Open link in browser
                                        // ignore: unawaited_futures
                                        launchUrlString(link);
                                      }
                                    },
                                    child: const PopupMenuDetails(
                                      icon: Icons.open_in_browser,
                                      text: 'Open in browser',
                                    ),
                                  ),
                                ];
                              },
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz),
                            ),
                          )
                        : Text(
                            widget.song?.trackTime != null
                                ? formatDuration(widget.song!.trackTime)
                                : formatDuration(0),
                            textAlign: TextAlign.left,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 70,
        color: Colors.white,
      ),
    );
  }

  String formatDuration(double durationInSeconds) {
    int minutes = durationInSeconds ~/ 60;
    int seconds = (durationInSeconds % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}  ';
  }
}

class PopupMenuDetails extends StatefulWidget {
  const PopupMenuDetails({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  State<PopupMenuDetails> createState() => _PopupMenuDetailsState();
}

class _PopupMenuDetailsState extends State<PopupMenuDetails> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          widget.icon,
          size: 20,
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        Text(
          widget.text,
          style: GoogleFonts.inter(
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isHovering,
    required this.onPressed,
    required this.thumbnailUrl,
  });

  final bool isHovering;
  final VoidCallback onPressed;
  final String? thumbnailUrl;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  bool _isButtonHovering = false;
  final _logger = getLogger('PlayButton');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                placeholder: (context, url) => _buildShimmerPlaceholder(),
                errorWidget: (context, url, error) {
                  _logger.e(error);
                  return const Icon(Icons.error);
                },
                height: 50,
                width: 50,
                fit: BoxFit.cover,
              )
            : _buildShimmerPlaceholder(),
        if (widget.isHovering)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              height: 50,
              width: 50,
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: MouseRegion(
                  onEnter: (event) {
                    setState(() {
                      _isButtonHovering = true;
                    });
                  },
                  onExit: (event) {
                    setState(() {
                      _isButtonHovering = false;
                    });
                  },
                  child: IconButton(
                    onPressed: () {
                      widget.onPressed();
                    },
                    padding: EdgeInsets.zero,
                    iconSize: _isButtonHovering ? 28 : 25,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }
}
