// router.dart
import 'package:flourish_web/auth/login_page.dart';
import 'package:flourish_web/auth/profile_page.dart';
import 'package:flourish_web/auth/signup/create_password.dart';
import 'package:flourish_web/auth/signup/name_page.dart';
import 'package:flourish_web/auth/signup/signup_page.dart';
import 'package:flourish_web/auth/subscription_page.dart';
import 'package:flourish_web/mobile_landing_page.dart';
import 'package:flourish_web/studyroom/study_page.dart';
import 'package:flutter/material.dart';
import 'package:get/utils.dart';
import 'package:go_router/go_router.dart';

enum AppRoute {
  home,
  studyRoom,
  signUpPage,
  enterNamePage,
  loginPage,
  createPasswordPage,
  profilePage,
  subscriptionPage,
}

GoRouter createRouter(BuildContext context) {
  bool isPhone = context.isPhone;
  bool isMobile = GetPlatform.isMobile;
  bool isPortrait = context.isPortrait;

  Widget initialPage;

  // Only show the mobile landing page if the user is on a phone or mobile device
  if (isPhone || isMobile || isPortrait) {
    initialPage = const MobileLandingPage();
  } else {
    initialPage = const StudyRoom();
  }

  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: initialPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/study-room',
        name: AppRoute.studyRoom.name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const StudyRoom(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/sign-up',
        name: AppRoute.signUpPage.name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignupPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/enter-name',
        name: AppRoute.enterNamePage.name,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          final name = extra?['name'];
          final password = extra?['password'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: EnterNamePage(username: name!, password: password!),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: AppRoute.profilePage.name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfilePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/login',
        name: AppRoute.loginPage.name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/subscribe',
        name: AppRoute.subscriptionPage.name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SubscriptionPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/create-password',
        name: AppRoute.createPasswordPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          final name = extra?['name'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: CreatePasswordPage(username: name!),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
    ],
  );
}
