import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/log_printer.dart';

class ErrorView extends StatelessWidget {
  final String errorMessage;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onGoBack;
  final _logger = getLogger('ErrorView');

  ErrorView({ // Made constructor const
    super.key,
    required this.errorMessage,
    required this.canRetry,
    required this.onRetry,
    required this.onGoBack,
  }) {
    _logger.d("Created with message: $errorMessage, canRetry: $canRetry");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget");
    return Padding(
      padding: const EdgeInsets.all(24.0), // Increased padding
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent.shade400, size: 56), // Softer red, larger icon
            const SizedBox(height: 20),
            Text(
              errorMessage.isNotEmpty ? errorMessage : "An unexpected error occurred.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17, // Slightly larger
                fontWeight: FontWeight.w500,
                color: Colors.redAccent.shade700, // Darker red for text
              ),
            ),
            const SizedBox(height: 30),
            if (canRetry)
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blueGrey.shade600, // Darker button
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: GoogleFonts.inter(fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () { _logger.i("Retry button tapped."); onRetry(); },
              ),
            const SizedBox(height: 12),
            TextButton(
              child: Text(
                "Go Back to Selection",
                style: GoogleFonts.inter(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
              ),
              onPressed: () { _logger.i("Go Back button tapped."); onGoBack(); },
            )
          ],
        ),
      ),
    );
  }
}
