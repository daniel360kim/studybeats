import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_tex/flutter_tex.dart';

class AiParser extends StatelessWidget {
  final String input;

  const AiParser(this.input);

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
          widgets.add(MarkdownBody(data: segment));
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
                  textStyle: const TextStyle(
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
        widgets.add(MarkdownBody(data: segment));
      }
    }

    return Column(
      children: widgets,
    );
  }
}
