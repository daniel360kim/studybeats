import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/studyroom/study_tools/aichat/profile.dart'; // Assuming this is your PulsatingCircle

// Assuming kStyleSheet is defined as in your original file
final kStyleSheet = MarkdownStyleSheet(
  p: GoogleFonts.inter(
    fontSize: 15,
  ),
  h1: GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
  h2: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  ),
  // Add other styles as needed, e.g., for code blocks, links, etc.
  code: GoogleFonts.sourceCodePro(
    // Example for code blocks
    backgroundColor: Colors.grey[200],

    textStyle: const TextStyle(fontSize: 14),
  ),
  blockquoteDecoration: BoxDecoration(
    // Example for blockquotes
    color: Colors.blue[50],
    border: Border(left: BorderSide(color: Colors.blue[200]!, width: 4)),
  ),
);

class AiMessage extends StatelessWidget {
  const AiMessage(
      {required this.isUser,
      required this.message,
      required this.profilePictureUrl,
      required this.onCopyIconPressed,
      required this.isLoadingResponse,
      required this.imageUrl, // This is for user-uploaded images in the message
      super.key});

  final bool isUser;
  final String message;
  final String? profilePictureUrl;
  final ValueChanged<String> onCopyIconPressed;
  final bool isLoadingResponse;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    late final String messageTitle;
    late final Widget profileImageWidget; // Renamed to avoid conflict

    if (isUser) {
      messageTitle = 'You';
      if (profilePictureUrl != null) {
        profileImageWidget = SizedBox(
          height: 30, // Slightly larger for better visibility
          width: 30,
          child: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(profilePictureUrl!),
            backgroundColor: Colors.grey[300], // Fallback color
          ),
        );
      } else {
        profileImageWidget = SizedBox(
          height: 30,
          width: 30,
          child: CircleAvatar(
            backgroundImage:
                AssetImage('assets/brand/logo.png'), // Ensure this asset exists
            backgroundColor: Colors.grey[300],
          ),
        );
      }
    } else {
      // AI Bot
      messageTitle = 'Studybeats Bot';
      if (isLoadingResponse) {
        profileImageWidget = SizedBox(
            height: 30,
            width: 30,
            child: Center(
                child: PulsatingCircle(size: 15, color: kFlourishAdobe)));
      } else {
        profileImageWidget = SizedBox(
            height: 30,
            width: 30,
            child: Center(
              child: CircleAvatar(
                backgroundColor: kFlourishAdobe,
                radius: 7, // Smaller solid circle
              ),
            ));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isUser
              ? kFlourishAdobe.withOpacity(0.08) // Softer user message color
              : Colors.white, // AI messages on white for contrast
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Align items vertically
            children: [
              profileImageWidget,
              const SizedBox(width: 8),
              // Wrap SelectableText with Expanded to prevent overflow if messageTitle is long
              Expanded(
                child: SelectableText(
                  messageTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14, // Slightly smaller title
                    color: kFlourishBlackish.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Keep copy button at the end of this row if it's for the title,
              // or move it to the message content row if it's for the message.
              // Assuming it's for the main message, it's in the correct place below.
            ],
          ),
          const SizedBox(height: 8), // Spacing after title row
          if (isUser && imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200, // Max height for inline images
                    maxWidth:
                        MediaQuery.of(context).size.width * 0.6, // Max width
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => SizedBox(
                        height: 100,
                        width: 100,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: kFlourishAdobe.withOpacity(0.5)))),
                    errorWidget: (context, url, error) => SizedBox(
                        height: 100,
                        width: 100,
                        child:
                            Icon(Icons.broken_image, color: Colors.grey[400])),
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align copy icon with top of message
            children: [
              Expanded(
                child: isUser
                    ? SelectableText(
                        message,
                        style: GoogleFonts.inter(
                            fontSize: 15, color: kFlourishBlackish),
                      )
                    : AiParser(message), // AiParser handles Markdown
              ),
              if (!isLoadingResponse) // Only show copy icon if not a loading placeholder
                IconButton(
                  icon: Icon(Icons.copy_outlined,
                      size: 18, color: Colors.grey[600]),
                  tooltip: "Copy message",
                  padding: const EdgeInsets.all(4), // Reduce padding
                  constraints: const BoxConstraints(), // Reduce constraints
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
    if (input.trim().isEmpty) {
      // Handle empty input gracefully, perhaps show a placeholder or nothing
      return SelectableText(" ",
          style: kStyleSheet.p); // Render empty space to maintain structure
    }

    List<Widget> widgets = [];
    // Regex to match LaTeX equations wrapped in $...$, $$...$$, \[...\], or \(...\)
    // This regex is simplified; a more robust one might be needed for complex cases.
    final regex = RegExp(
        r'(\$\$[\s\S]+?\$\$|\$[\s\S]+?\$|\\\[[\s\S]+?\\\]|\\\(.+?\\\))',
        dotAll: true);
    final segments = input.split(regex);
    final matches = regex.allMatches(input).toList();

    int currentSegment = 0;
    for (int i = 0; i < segments.length; i++) {
      // Add plain text segment
      if (segments[i].isNotEmpty) {
        widgets.add(MarkdownBody(
          data: segments[i],
          selectable: true,
          styleSheet: kStyleSheet,
          softLineBreak: true, // Ensure line breaks are rendered
        ));
      }
      // Add matched LaTeX segment if it exists
      if (i < matches.length) {
        final latexMatch = matches[i].group(0)!;
        String latexContent = latexMatch;
        // Remove delimiters for rendering, assuming flutter_markdown handles LaTeX with them
        // Or, if you have a specific LaTeX rendering widget, prepare content for it.
        // For flutter_markdown, it might expect $...$ or $$...$$ directly.

        // Example: if it's for katex rendering, you might strip delimiters
        // if (latexContent.startsWith(r'\(') && latexContent.endsWith(r'\)')) {
        //   latexContent = latexContent.substring(2, latexContent.length - 2);
        // } else if (latexContent.startsWith(r'\[') && latexContent.endsWith(r'\]')) {
        //   latexContent = latexContent.substring(2, latexContent.length - 2);
        // } else if (latexContent.startsWith(r'$$') && latexContent.endsWith(r'$$')) {
        //   latexContent = latexContent.substring(2, latexContent.length - 2);
        // } else if (latexContent.startsWith(r'$') && latexContent.endsWith(r'$')) {
        //   latexContent = latexContent.substring(1, latexContent.length - 1);
        // }

        widgets.add(Padding(
          // Add some padding around LaTeX blocks
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: SingleChildScrollView(
            // For potentially wide LaTeX
            scrollDirection: Axis.horizontal,
            child: MarkdownBody(
              data: latexMatch, // Pass the original match with delimiters
              selectable: true,
              styleSheet: kStyleSheet,
            ),
          ),
        ));
      }
    }

    if (widgets.isEmpty && input.isNotEmpty) {
      // Fallback if regex splitting results in no widgets but input exists
      widgets.add(MarkdownBody(
          data: input,
          selectable: true,
          styleSheet: kStyleSheet,
          softLineBreak: true));
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Important for children alignment
      mainAxisSize: MainAxisSize.min, // Take only necessary vertical space
      children: widgets,
    );
  }
}
