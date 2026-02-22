/// Non-web: заглушка (desktop/mobile).
Future<void> downloadText(String content, String filename) async {
  throw UnsupportedError('Скачивание доступно только в web-версии');
}
