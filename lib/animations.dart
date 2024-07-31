import 'package:flutter/material.dart';
import 'dart:ui';

Route swipe(Widget page, Offset begin, Offset end, Duration duration) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(curve),
        child: child,
      );
    },
    transitionDuration: duration,
  );
}

Route swipeLeft(Widget page, Duration duration) {
  return swipe(page, const Offset(1, 0), Offset.zero, duration);
}

Route swipeRight(Widget page, Duration duration) {
  return swipe(page, const Offset(-1, 0), Offset.zero, duration);
}

Route swipeUp(Widget page, Duration duration) {
  return swipe(page, const Offset(0, 1), Offset.zero, duration);
}

Route swipeDown(Widget page, Duration duration) {
  return swipe(page, const Offset(0, -1), Offset.zero, duration);
}

Route zoomIn(Widget page, Duration duration) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return ScaleTransition(
        scale: Tween<double>(
          begin: 0.5,
          end: 1,
        ).animate(curve),
        child: child,
      );
    },
    transitionDuration: duration,
  );
}


Route fade(Widget page, Duration duration) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(
        opacity: Tween<double>(
          begin: 0,
          end: 1,
        ).animate(curve),
        child: child,
      );
    },
    transitionDuration: duration,
  );
}

Route noTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

Route blurDissolve(Widget page, Duration duration) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(
        opacity: Tween<double>(
          begin: 0,
          end: 1,
        ).animate(curve),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * (1 - curve.value),
            sigmaY: 10 * (1 - curve.value),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: duration,
  );
}
