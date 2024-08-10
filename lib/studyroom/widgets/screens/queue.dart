import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class SongQueue extends StatefulWidget {
  const SongQueue({
    super.key,
    required this.currentSong,
    required this.queue,
    required this.songOrder,
    required this.onSongSelected,
  });

  final SongMetadata currentSong;
  final List<SongMetadata> queue;
  final List<SongMetadata> songOrder;
  final ValueChanged<int> onSongSelected;

  @override
  State<SongQueue> createState() => _SongQueueState();
}

class _SongQueueState extends State<SongQueue> {
  final borderRadius = const BorderRadius.only(
    topLeft: Radius.circular(40.0),
    topRight: Radius.circular(40.0),
  );

  // Method to find the index of the song in the songOrder based on its index in the queue
  int getSongOrderIndex(int queueIndex) {
    if (queueIndex < 0 || queueIndex >= widget.queue.length) {
      return -1; // Return -1 if index is out of bounds
    }

    final songInQueue = widget.queue[queueIndex];
    return widget.songOrder.indexWhere((song) => song.id == songInQueue.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 10, left: 10),
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
                const SizedBox(height: 40),
                buildCurrentSong(),
                const SizedBox(height: 10),
                buildQueue(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return const Align(
      alignment: Alignment.topLeft,
      child: Text(
        'Queue',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  // In the buildCurrentSong method
  Widget buildCurrentSong() {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            'Playing Now',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          QueueSongItem(
            song: widget.currentSong,
            onPressed: () {
              // Find the index of the current song in the queue
              final queueIndex = widget.queue.indexWhere((song) => song.id == widget.currentSong.id);
              final songOrderIndex = getSongOrderIndex(queueIndex);
              widget.onSongSelected(songOrderIndex);
            },
          ),
        ],
      ),
    );
  }

  // In the buildQueue method
  Widget buildQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Up Next',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.of(context).size.height - 80 * 2 - 289,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.queue.length,
            itemBuilder: (context, index) {
              return QueueSongItem(
                song: widget.queue[index],
                onPressed: () {
                  final songOrderIndex = getSongOrderIndex(index);
                  widget.onSongSelected(songOrderIndex); // Use the index directly
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class QueueSongItem extends StatefulWidget {
  const QueueSongItem({required this.song, required this.onPressed, super.key});

  final SongMetadata song;
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
            color: _isHovering ? Colors.grey.withOpacity(0.5) : Colors.transparent,
          ),
          child: Row(
            children: [
              PlayButton(
                isHovering: _isHovering,
                onPressed: widget.onPressed,
                thumbnailUrl: widget.song.artworkUrl100,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.trackName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    widget.song.artistName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _isHovering
                  ? Theme(
                      data: ThemeData(
                        popupMenuTheme: const PopupMenuThemeData(
                            elevation: 5, color: Color.fromRGBO(57, 57, 57, 1)),
                      ),
                      child: PopupMenuButton(
                        itemBuilder: (context) {
                          return [
                            const PopupMenuItem(
                              child: PopupMenuDetails(
                                icon: Icons.info,
                                text: 'Details',
                              ),
                            ),
                            const PopupMenuItem(
                              child: PopupMenuDetails(
                                icon: Icons.share,
                                text: 'Share',
                              ),
                            ),
                          ];
                        },
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz),
                      ),
                    )
                  : Text(
                      formatDuration(widget.song.trackTime),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontFamily: 'Inter',
                      ),
                    ),
            ],
          ),
        ),
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
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
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
  final String thumbnailUrl;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  bool _isButtonHovering = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: widget.thumbnailUrl,
          height: 50,
          width: 50,
          fit: BoxFit.cover,
        ),
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
}
