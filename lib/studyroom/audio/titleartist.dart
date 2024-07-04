import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class Title extends StatelessWidget {
  const Title({required this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return title != null && title!.length > 15
        ? Marquee(
            text: title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: 20.0,
            velocity: 23,
            startPadding: 10.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          )
        : Text(
            title ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          );
  }
}

class TitleArtist extends StatelessWidget {
  const TitleArtist({required this.title, required this.artist, super.key});

  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 180, height: 25, child: Title(title: title)),
        const SizedBox(height: 5),
        artist != null && artist!.length > 15
            ? SizedBox(
                width: 180,
                height: 25,
                child: Marquee(
                  text: artist!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                  scrollAxis: Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  blankSpace: 20.0,
                  velocity: 23,
                  startPadding: 10.0,
                  accelerationDuration: const Duration(seconds: 1),
                  accelerationCurve: Curves.linear,
                  decelerationDuration: const Duration(milliseconds: 500),
                  decelerationCurve: Curves.easeOut,
                ),
              )
            : Text(
                artist ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
      ],
    );
  }
}
