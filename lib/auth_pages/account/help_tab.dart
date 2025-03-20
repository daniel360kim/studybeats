import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:studybeats/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpTab extends StatefulWidget {
  const HelpTab({super.key});

  @override
  _HelpTabState createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> {
  String _appVersion = "Loading...";
  String _buildNumber = "Loading...";
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAppInfo();
  }

  Future<void> _fetchAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Information Section
          Card(
            color: kFlourishAliceBlue.withOpacity(0.1),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("About StudyBeats",
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kFlourishAliceBlue)),
                  SizedBox(height: 8),
                  Text("Version: $_appVersion",
                      style: GoogleFonts.inter(color: kFlourishAliceBlue)),
                  Text("Developer: StudyBeats Team",
                      style: GoogleFonts.inter(color: kFlourishAliceBlue)),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(color: kFlourishAliceBlue),
                      text: 'Support Email: ',
                      children: [
                        TextSpan(
                          text: 'support@studybeats.co',
                          style: GoogleFonts.inter(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl('mailto:support@studybeats.co');
                            },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(color: kFlourishAliceBlue),
                      text: 'Website: ',
                      children: [
                        TextSpan(
                          text: 'https://studybeats.co',
                          style: GoogleFonts.inter(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl('https://studybeats.co');
                            },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
