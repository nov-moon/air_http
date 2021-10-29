import 'dart:io';

import 'package:http/io_client.dart';

class HttpUtils {
  static IOClient getClient() {
    var client = ignoreCertificateClient();
    return client;
  }

  static bool _certificateCheck(X509Certificate cert, String host, int port) =>
      true;

  static IOClient ignoreCertificateClient() {
    var ioClient = new HttpClient()..badCertificateCallback = _certificateCheck;

    return new IOClient(ioClient);
  }
}
