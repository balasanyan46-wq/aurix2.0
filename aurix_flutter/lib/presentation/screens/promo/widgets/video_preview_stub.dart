import 'package:flutter/material.dart';

/// Fallback for non-web platforms — shows a placeholder.
Widget buildVideoPreview(String url) {
  return const SizedBox(
    height: 200,
    child: Center(
      child: Text(
        'Превью доступно только в браузере',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
    ),
  );
}
