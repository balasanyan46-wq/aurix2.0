import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Accept self-signed certificates on native platforms.
/// TODO: Remove when a real SSL certificate is configured.
void configureDio(Dio dio) {
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  };
}
