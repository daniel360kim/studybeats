import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart'; // Assuming kFlourishAdobe is here
import 'package:studybeats/log_printer.dart';

class LoadingView extends StatelessWidget {
  final String message;
  final _logger = getLogger('LoadingView');

  LoadingView({ // Made constructor const
    super.key,
    required this.message,
  }) {
    _logger.d("Created with message: $message");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget");
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: kFlourishAdobe,
              strokeWidth: 3.0,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
