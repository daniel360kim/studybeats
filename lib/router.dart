// router.dart
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/auth_pages/account/account_page.dart';
import 'package:studybeats/auth_pages/login_page.dart';
import 'package:studybeats/auth_pages/profile_page.dart';
import 'package:studybeats/auth_pages/signup/create_password.dart';
import 'package:studybeats/auth_pages/signup/forgot_password.dart';
import 'package:studybeats/auth_pages/signup/name_page.dart';
import 'package:studybeats/auth_pages/signup/signup_page.dart';
import 'package:studybeats/landing/error_page.dart';
import 'package:studybeats/landing/mobile_landing_page.dart';
import 'package:studybeats/studyroom/study_page.dart';
import 'package:flutter/material.dart';
import 'package:get/utils.dart';
import 'package:go_router/go_router.dart';

class ScreenViewObserver extends NavigatorObserver {
  final AnalyticsService analyticsService;

  ScreenViewObserver({required this.analyticsService});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _logScreenView(previousRoute);
    }
  }

  void _logScreenView(Route<dynamic> route) {
    final name = route.settings.name ?? 'Unknown';
    analyticsService.logScreenView(
      screenName: name,
      screenClass: name,
    );
  }
}

enum AppRoute {
  home,
  studyRoom,
  signUpPage,
  enterNamePage,
  loginPage,
  createPasswordPage,
  profilePage,
  forgotPassword,
  accountPage,
  getPro,
}

GoRouter createRouter(BuildContext context) {
  bool isTablet = GetPlatform.isTablet;

  Widget initialPage;

  // Only show the mobile landing page if the user is on a tablet
  if (isTablet) {
    initialPage = const MobileLandingPage();
  } else {
    initialPage = const StudyRoom();
  }

  return GoRouter(
    errorBuilder: (context, state) => const ErrorPage(),
    observers: [
      ScreenViewObserver(
        analyticsService: AnalyticsService(),
      ),
    ],
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          name: AppRoute.home.name,
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
          name: AppRoute.studyRoom.name,
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
          name: AppRoute.signUpPage.name,
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
          return CustomTransitionPage(
            name: AppRoute.enterNamePage.name,
            key: state.pageKey,
            child: const EnterNamePage(),
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
          name: AppRoute.profilePage.name,
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
          name: AppRoute.loginPage.name,
          key: state.pageKey,
          child: const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
   
      GoRoute(
        path: '/create-password',
        name: AppRoute.createPasswordPage.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            name: AppRoute.createPasswordPage.name,
            key: state.pageKey,
            child: const CreatePasswordPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: AppRoute.forgotPassword.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            name: AppRoute.createPasswordPage.name,
            key: state.pageKey,
            child: const ForgotPasswordPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/account',
        name: AppRoute.accountPage.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            name: AppRoute.accountPage.name,
            key: state.pageKey,
            child: const AccountPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/get_pro',
        name: AppRoute.getPro.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            name: AppRoute.getPro.name,
            key: state.pageKey,
            child: const StudyRoom(openPricing: true),
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
