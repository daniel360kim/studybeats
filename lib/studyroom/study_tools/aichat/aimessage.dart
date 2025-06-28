import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/studyroom/study_tools/aichat/profile.dart';
import 'package:studybeats/theme_provider.dart';

MarkdownStyleSheet _createStyleSheet(ThemeProvider themeProvider) {
  final isDark = themeProvider.isDarkMode;

  // Define colors for code blocks based on the theme
  final codeBlockBackgroundColor =
      isDark ? const Color(0xFF282C34) : const Color(0xFFF6F8FA);
  final codeTextColor =
      isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42);
  final codeBlockBorderColor =
      isDark ? const Color(0xFF3A4048) : const Color(0xFFE1E4E8);

  return MarkdownStyleSheet(
    p: GoogleFonts.inter(
      fontSize: 14,
      color: themeProvider.mainTextColor,
    ),
    h1: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    h2: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    h3: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    h4: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    h5: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    h6: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: themeProvider.mainTextColor,
    ),
    listBullet: GoogleFonts.inter(
      fontSize: 14,
      color: themeProvider.mainTextColor,
    ),
    // This style now applies to the text within the code block.
    // The background is set to transparent because the container decoration handles it.
    code: GoogleFonts.sourceCodePro(
      color: codeTextColor,
      backgroundColor: Colors.transparent,
      fontSize: 14,
    ),
    // This new property styles the container of a fenced code block.
    codeblockDecoration: BoxDecoration(
      color: codeBlockBackgroundColor,
      borderRadius: BorderRadius.circular(8.0),
      border: Border.all(color: codeBlockBorderColor),
    ),
    blockquoteDecoration: BoxDecoration(
      color: themeProvider.primaryAppColor.withOpacity(0.1),
      border: Border(
        left: BorderSide(color: themeProvider.primaryAppColor, width: 4),
      ),
    ),
  );
}

class AiMessage extends StatelessWidget {
  const AiMessage(
      {required this.isUser,
      required this.message,
      required this.profilePictureUrl,
      required this.onCopyIconPressed,
      required this.isLoadingResponse,
      required this.imageUrl,
      super.key});

  final bool isUser;
  final String message;
  final String? profilePictureUrl;
  final ValueChanged<String> onCopyIconPressed;
  final bool isLoadingResponse;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    late final String messageTitle;
    late final Widget profileImageWidget;

    if (isUser) {
      messageTitle = 'You';
      if (profilePictureUrl != null) {
        profileImageWidget = SizedBox(
          height: 30,
          width: 30,
          child: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(profilePictureUrl!),
            backgroundColor: Colors.grey[300],
          ),
        );
      } else {
        profileImageWidget = SizedBox(
          height: 30,
          width: 30,
          child: CircleAvatar(
            backgroundImage: const AssetImage('assets/brand/logo.png'),
            backgroundColor: Colors.grey[300],
          ),
        );
      }
    } else {
      messageTitle = 'Studybeats Bot';
      if (isLoadingResponse) {
        profileImageWidget = SizedBox(
            height: 30,
            width: 30,
            child: Center(
                child: PulsatingCircle(
                    size: 15, color: themeProvider.primaryAppColor)));
      } else {
        profileImageWidget = SizedBox(
            height: 30,
            width: 30,
            child: Center(
              child: CircleAvatar(
                backgroundColor: themeProvider.primaryAppColor,
                radius: 7,
              ),
            ));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isUser
              ? themeProvider.userMessageBackgroundColor
              : themeProvider.aiMessageBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!themeProvider.isDarkMode)
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              profileImageWidget,
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  messageTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: themeProvider.mainTextColor.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isUser && imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => SizedBox(
                        height: 100,
                        width: 100,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: themeProvider.primaryAppColor
                                    .withOpacity(0.5)))),
                    errorWidget: (context, url, error) => SizedBox(
                        height: 100,
                        width: 100,
                        child: Icon(Icons.broken_image,
                            color: themeProvider.secondaryTextColor)),
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isUser
                    ? SelectableText(
                        message,
                        style: GoogleFonts.inter(
                            fontSize: 15, color: themeProvider.mainTextColor),
                      )
                    : AiParser(message),
              ),
              if (!isLoadingResponse)
                IconButton(
                  icon: Icon(Icons.copy_outlined,
                      size: 18, color: themeProvider.secondaryTextColor),
                  tooltip: "Copy message",
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final styleSheet = _createStyleSheet(themeProvider);

    if (input.trim().isEmpty) {
      return SelectableText(" ", style: styleSheet.p);
    }

    final regex = RegExp(
        r'(\$\$[\s\S]+?\$\$|\$[\s\S]+?\$|\\\[[\s\S]+?\\\]|\\\(.+?\\\))',
        dotAll: true);
    final segments = input.split(regex);
    final matches = regex.allMatches(input).toList();
    List<Widget> widgets = [];
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].isNotEmpty) {
        widgets.add(MarkdownBody(
          data: segments[i],
          selectable: true,
          styleSheet: styleSheet,
          softLineBreak: true,
        ));
      }

      if (i < matches.length) {
        final latexMatch = matches[i].group(0)!;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MarkdownBody(
              data: latexMatch,
              selectable: true,
              styleSheet: styleSheet,
            ),
          ),
        ));
      }
    }

    if (widgets.isEmpty && input.isNotEmpty) {
      widgets.add(MarkdownBody(
          data: input,
          selectable: true,
          styleSheet: styleSheet,
          softLineBreak: true));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}
