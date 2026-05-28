import 'package:flutter/material.dart';

/// Full-screen route timings (feed → article, bookmarks, in-app browser).
const Duration kNyusRouteEnterDuration = Duration(milliseconds: 520);
const Duration kNyusRouteExitDuration = Duration(milliseconds: 440);

/// Shared “stack push” motion: fade + horizontal slide + light scale.
class NyusPageTransitions {
  NyusPageTransitions._();

  static Route<T> pushRoute<T extends Object?>(
    Widget page, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: kNyusRouteEnterDuration,
      reverseTransitionDuration: kNyusRouteExitDuration,
      opaque: true,
      maintainState: true,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInQuart,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.965, end: 1).animate(curved),
              alignment: const Alignment(0.85, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
