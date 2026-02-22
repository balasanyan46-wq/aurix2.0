import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class LegalFieldInput extends StatelessWidget {
  const LegalFieldInput({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(color: AurixTokens.text, fontSize: 14),
        decoration: InputDecoration(
          labelText: label.replaceAll('_', ' '),
          labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
          filled: true,
          fillColor: AurixTokens.glass(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AurixTokens.stroke()),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
