String formatApiError(Object error) {
  final text = error.toString();
  return text.replaceFirst('Exception: ', '').trim();
}
