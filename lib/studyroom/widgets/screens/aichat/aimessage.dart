import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/auth/urls.dart';
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

final kStyleSheet = MarkdownStyleSheet(
  p: GoogleFonts.inter(
    fontSize: 15,
  ),
  h1: GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
  h2: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  ),
);

class AiMessage extends StatelessWidget {
  const AiMessage(
      {required this.isUser,
      required this.message,
      required this.profilePictureUrl,
      required this.onCopyIconPressed,
      required this.isLoadingResponse,
      required this.imageFile,
      super.key});

  final bool isUser;
  final String message;
  final String? profilePictureUrl;
  final ValueChanged<String> onCopyIconPressed;
  final bool isLoadingResponse;
  final Uint8List? imageFile;

  @override
  Widget build(BuildContext context) {
    late final String messageTitle;
    late final Widget profileImage;

    if (isUser) {
      messageTitle = 'You';
      if (profilePictureUrl != null) {
        profileImage = SizedBox(
          height: 20,
          width: 20,
          child: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(profilePictureUrl!),
          ),
        );
      } else {
        profileImage = const SizedBox(
          height: 20,
          width: 20,
          child: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(kBlankProfilePicture),
          ),
        );
      }
    } else {
      profileImage = Container(
        height: 10,
        width: 10,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: kFlourishPurple,
        ),
      );
      messageTitle = 'ChatGPT';
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUser
            ? kFlourishAdobe.withOpacity(0.5)
            : Colors.blue[100]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              profileImage,
              const SizedBox(width: 5),
              SelectableText(
                messageTitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: kFlourishBlackish,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
          if (isUser && imageFile != null)
            Container(
              height: 140,
              width: 140,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                  image: DecorationImage(
                fit: BoxFit.cover,
                image: MemoryImage(imageFile!),
              )),
            ),
          Row(
            children: [
              Expanded(
                child: isUser
                    ? SelectableText(
                        message,
                        style: GoogleFonts.inter(fontSize: 16),
                      )
                    : isLoadingResponse
                        ? SizedBox(
                            height: 10,
                            width: 20,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: Lottie.asset(
                                'assets/animations/loading_dots.json',
                                height: 100,
                                width: 200,
                                fit: BoxFit.fill,
                              ),
                            ),
                          )
                        : AiParser(message),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => onCopyIconPressed(message),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiParser extends StatelessWidget {
  final String input;

  const AiParser(this.input, {super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = [];
    // Regex to match LaTeX equations wrapped in \[...\] or \(...\)
    final regex = RegExp(r'(\\\[.+?\\\]|\\\(.+?\\\))', dotAll: true);
    final segments = input.split(regex);

    final matches = regex.allMatches(input).toList();
    int segmentIndex = 0;

    for (var match in matches) {
      // Add plain text before the match
      if (segmentIndex < segments.length) {
        final segment = segments[segmentIndex];
        if (segment.isNotEmpty) {
          widgets.add(MarkdownBody(
            data: segment,
            selectable: true,
            styleSheet: kStyleSheet,
          ));
        }
        segmentIndex++;
      }

      // Add LaTeX equation
      final latex = match.group(0);
      if (latex != null) {
        ScrollController scrollController = ScrollController();
        final content = latex.substring(
            2, latex.length - 2); // Remove \[ and \] or \( and \)
        widgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Scrollbar(
              controller: scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                child: Math.tex(
                  content,
                  textStyle: GoogleFonts.inter(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Add any remaining plain text after the last match
    if (segmentIndex < segments.length) {
      final segment = segments[segmentIndex];
      if (segment.isNotEmpty) {
        widgets.add(MarkdownBody(
          data: segment,
          selectable: true,
          styleSheet: kStyleSheet,
        ));
      }
    }

    return Column(
      children: widgets,
    );
  }
}
