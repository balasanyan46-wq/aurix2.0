/// AI chat message model.
class AiMessage {
  final String role;  // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime ts;

  AiMessage({
    required this.role,
    required this.content,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'ts': ts.toIso8601String(),
      };

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      ts: json['ts'] != null
          ? DateTime.tryParse(json['ts'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
