import 'package:studybeats/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginTextField extends StatefulWidget {
  const LoginTextField(
      {required this.controller,
      required this.onChanged,
      required this.hintText,
      required this.keyboardType,
      this.obscureText = false,
      this.valid = true,
      super.key});

  final TextEditingController controller;
  final ValueChanged onChanged;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool valid;

  @override
  State<LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<LoginTextField> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },
      child: SizedBox(
        width: 350,
        height: 55,
        child: CupertinoTextField(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _hovering
                  ? kFlourishAliceBlue
                  : widget.valid
                      ? kFlourishAliceBlue.withOpacity(0.7)
                      : Colors.red,
              width: 1,
            ),
          ),
          placeholder: widget.hintText,
          placeholderStyle: GoogleFonts.inter(
            color: kFlourishLightBlackish,
            fontSize: 15,
          ),
          style: GoogleFonts.inter(
            color: kFlourishAliceBlue,
            fontSize: 15,
          ),
          cursorColor: kFlourishAliceBlue,
          keyboardType: widget.keyboardType,
          textInputAction: TextInputAction.next,
          onChanged: (value) {
            widget.onChanged(value);
          },
          obscureText: widget.obscureText,
        ),
      ),
    );
  }
}
