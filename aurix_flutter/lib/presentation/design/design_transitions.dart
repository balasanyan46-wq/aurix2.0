import 'package:flutter/material.dart';

/// Кастомный transition: slide + fade + slight scale
PageRouteBuilder<T> designPageRoute<T>({required Widget page}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.03, 0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      var slide = Tween<Offset>(begin: begin, end: end).animate(CurvedAnimation(parent: animation, curve: curve));
      var fade = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: animation, curve: curve));
      var scale = Tween<double>(begin: 0.98, end: 1).animate(CurvedAnimation(parent: animation, curve: curve));
      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}
