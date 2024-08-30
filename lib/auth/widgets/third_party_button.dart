
import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CredentialSigninButton extends StatefulWidget {
  const CredentialSigninButton({
    required this.backgroundColor,
    required this.logoPath,
    required this.text,
    required this.onPressed,
    super.key,
  });

  final Color backgroundColor;
  final String logoPath;
  final String text;
  final VoidCallback onPressed;

  @override
  State<CredentialSigninButton> createState() => _CredentialSigninButtonState();
}

class _CredentialSigninButtonState extends State<CredentialSigninButton> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // Ensure the Material widget is transparent
      child: InkWell(
        borderRadius: BorderRadius.circular(30), // Match the border radius
        onTap: widget.onPressed,
        onHover: (hovering) {
          setState(() {
            _hovering = hovering;
          });
        },
        splashColor: kFlourishAliceBlue
            .withOpacity(0.3), // Optional: customize splash color
        child: Container(
          padding: const EdgeInsets.all(10),
          height: 50,
          width: 350,
          decoration: BoxDecoration(
            border: Border.all(
              color: kFlourishAliceBlue.withOpacity(0.7),
              width: _hovering ? 2 : 1, // Adjust border width on hover
            ),
            color: _hovering
                ? widget.backgroundColor.withOpacity(0.9)
                : widget.backgroundColor, // Adjust color on hover
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(widget.logoPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    color: kFlourishAliceBlue,
                    fontSize: 16,
    
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

