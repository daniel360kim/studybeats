import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/worlddata/views.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:url_launcher/url_launcher.dart';

class SongCredits extends StatefulWidget {
  const SongCredits({
    super.key,
    required this.song,
  });

  final Song song;

  @override
  State<SongCredits> createState() => _SongCreditsState();
}

class _SongCreditsState extends State<SongCredits> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 10),
      width: 500,
      height: MediaQuery.of(context).size.height - 80 * 10,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(170, 170, 170, 0.7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40.0),
                topRight: Radius.circular(40.0),
              ),
            ),
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                buildHeader(),
                const SizedBox(height: 10),
                buildInformation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: 500,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            elevation: 3,
            child: ClipRRect(
              child: CachedNetworkImage(
                imageUrl: buildThumbnailRequest(3),
                height: 110,
                width: 110,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.song.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.song.artist,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildInformation() {
    return Container(
      width: 500,
      height: 321,
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
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Duration: ${formatDuration(widget.song.duration)}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => _launchUrl(widget.song.link),
            child: Text(
              'Link: ${widget.song.link}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    if (url == 'Loading...') {
      return;
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  String formatDuration(double duration) {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();

    String formattedSeconds = seconds.toString();
    if (seconds < 10) {
      formattedSeconds = '0$formattedSeconds';
    }

    String formattedMinutes = minutes.toString();
    if (minutes < 10) {
      formattedMinutes = '0$formattedMinutes';
    }

    return '$formattedMinutes:$formattedSeconds';
  }
}
