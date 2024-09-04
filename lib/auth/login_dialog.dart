import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/auth/widgets/textfield.dart';
import 'package:flourish_web/auth/widgets/third_party_button.dart';

class LoginDialog extends StatelessWidget {
  final String title;
  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isError;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onPasswordVisibilityToggle;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;

  const LoginDialog({
    super.key,
    required this.title,
    required this.email,
    required this.password,
    required this.isPasswordVisible,
    required this.onConfirm,
    required this.onGoogleSignIn,
    required this.onPasswordVisibilityToggle,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    this.isError = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kFlourishBlackish,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: kFlourishAliceBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              CredentialSigninButton(
                onPressed: onGoogleSignIn,
                backgroundColor: Colors.transparent,
                logoPath: 'assets/brand/google.png',
                text: 'Sign in with Google',
              ),
              const SizedBox(height: 20),
              buildTextFields(),
              const SizedBox(height: 20),
              if (isError)
                Text(
                  'Incorrect email or password',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator(
                      color: kFlourishAdobe,
                    )
                  : ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kFlourishLightBlue,
                        minimumSize: const Size(150, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Log in',
                        style: GoogleFonts.inter(
                          color: kFlourishBlackish,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextFields() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email',
            style: GoogleFonts.inter(
              color: kFlourishAliceBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LoginTextField(
          controller: TextEditingController(text: email),
          onChanged: (_) {},
          hintText: 'Email',
          keyboardType: TextInputType.emailAddress,
          valid: true, // Adjust based on your validation logic
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Password',
              style: GoogleFonts.inter(
                color: kFlourishAliceBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: kFlourishAliceBlue,
              ),
              onPressed: onPasswordVisibilityToggle,
            ),
          ],
        ),
        const SizedBox(height: 5),
        LoginTextField(
          controller: TextEditingController(text: password),
          onChanged: (_) {},
          hintText: 'Password',
          keyboardType: TextInputType.visiblePassword,
          obscureText: !isPasswordVisible,
          valid: true, // Adjust based on your validation logic
        ),
      ],
    );
  }
}
