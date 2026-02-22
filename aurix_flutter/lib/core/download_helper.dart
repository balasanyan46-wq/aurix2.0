import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

Future<void> downloadText(String content, String filename) =>
    impl.downloadText(content, filename);
