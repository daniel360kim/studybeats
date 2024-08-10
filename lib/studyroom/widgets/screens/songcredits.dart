import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/audio/audio_service.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flourish_web/studyroom/widgets/screens/queue.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SongCredits extends StatefulWidget {
  const SongCredits({
    super.key,
    required this.song,
  });

  final SongMetadata song;

  @override
  State<SongCredits> createState() => _SongCreditsState();
}

enum InfoType {
  details,
  artwork,
  album,
}

class _SongCreditsState extends State<SongCredits> {
  InfoType _selectedSegment = InfoType.details;

  WaveformMetadata _metadata =
      WaveformMetadata(sampleRate: 0, channels: 1, bitDepth: 0);

  Future loadSongInfo() async {
    final audioService = AudioService();

    return audioService.getWaveformMetadata(widget.song.waveformPath);
  }

  @override
  void initState() {
    super.initState();
    loadSongInfo().then((value) {
      setState(() => _metadata = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(40.0),
      topRight: Radius.circular(40.0),
    );
    return Container(
      padding: const EdgeInsets.only(right: 10),
      width: 500,
      height: MediaQuery.of(context).size.height - 80 * 5,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(170, 170, 170, 0.7),
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.all(10.0),
            child: buildAdditionalInfo(),
          ),
        ),
      ),
    );
  }

  Widget buildAdditionalInfo() {
    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 500,
            child: CupertinoSegmentedControl<InfoType>(
              selectedColor: kFlourishLightBlue,
              unselectedColor: Colors.white,
              borderColor: kFlourishLightBlue,
              children: const {
                InfoType.details:
                    Text('Details', style: TextStyle(fontFamily: 'Inter')),
                InfoType.artwork:
                    Text('Artwork', style: TextStyle(fontFamily: 'Inter')),
                InfoType.album:
                    Text('Album', style: TextStyle(fontFamily: 'Inter')),
              },
              onValueChanged: (InfoType value) {
                setState(() {
                  _selectedSegment = value;
                });
              },
              groupValue: _selectedSegment,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: switch (_selectedSegment) {
              InfoType.details => buildDetails(),
              InfoType.artwork => buildArtwork(),
              InfoType.album => buildAlbum(),
            },
          ),
        ],
      ),
    );
  }

  Widget buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.song.trackName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const Spacer(),
            Theme(
              data: ThemeData(
                popupMenuTheme: const PopupMenuThemeData(
                    elevation: 5, color: Color.fromRGBO(57, 57, 57, 1)),
              ),
              child: PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      child: const PopupMenuDetails(
                        icon: Icons.copy,
                        text: 'Copy link',
                      ),
                      onTap: () {
                        Clipboard.setData(
                                ClipboardData(text: widget.song.youtubeLink))
                            .then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copied to clipboard')),
                          );
                        });
                      }, // TODO copy the song link on tap
                    ),
                    PopupMenuItem(
                      child: const PopupMenuDetails(
                        icon: Icons.open_in_browser,
                        text: 'Open',
                      ),
                      onTap: () async {
                        if (await canLaunchUrl(
                            Uri.parse(widget.song.youtubeLink))) {
                          await launchUrl(Uri.parse(widget.song.youtubeLink));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not launch URL')),
                          );
                        }
                      }, // TODO open the song in the app
                    ),
                  ];
                },
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.ios_share),
              ),
            )
          ],
        ),
        const SizedBox(height: 13),
        getInfoText('Artist', widget.song.artistName),
        const SizedBox(height: 3),
        getInfoText('Duration', convertDuration(widget.song.trackTime)),
        const SizedBox(height: 16),
        getInfoText('Sample Rate', '${_metadata.sampleRate} Hz'),
        const SizedBox(height: 3),
        getInfoText('Channels', '${_metadata.channels}'),
        const SizedBox(height: 3),
        getInfoText('Bit Depth', '${_metadata.bitDepth} bits'),
      ],
    );
  }

  RichText getInfoText(String heading, String text) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$heading: ',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Inter',
            ),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildArtwork() {
    return Center(
      child: CachedNetworkImage(
        imageUrl: widget.song.artworkUrl100.replaceAll('100x100', '600x600'),
        width: 500,
        height: 500,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget buildAlbum() {
    return const Column(
      children: [
        Text(
          'Album:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  String convertDuration(double duration) {
    final int minutes = (duration / 60).floor();
    final int seconds = (duration % 60).floor();

    String minutesStr = '';
    if (minutes < 10) {
      minutesStr = '0$minutes';
    } else {
      minutesStr = minutes.toString();
    }

    String secondsStr = '';
    if (seconds < 10) {
      secondsStr = '0$seconds';
    } else {
      secondsStr = seconds.toString();
    }

    return '$minutesStr:$secondsStr';
  }
}
