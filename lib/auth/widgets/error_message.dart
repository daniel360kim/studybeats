
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorMessage extends StatelessWidget {
  const ErrorMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        children: [
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                message,
                style:  GoogleFonts.inter(
                  color: Colors.red,
                  fontSize: 12,

                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
