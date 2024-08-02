import 'package:flourish_web/colors.dart';
import 'package:flutter/material.dart';

class UnknownError extends StatelessWidget {
  const UnknownError({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.all(
            Radius.circular(25.0),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: kFlourishAliceBlue,
            ),
            SizedBox(width: 5),
            Text(
              'Something went wrong.',
              style: TextStyle(color: kFlourishAliceBlue, fontFamily: 'Inter'),
            ),
          ],
        ),
      ),
    );
  }
}
