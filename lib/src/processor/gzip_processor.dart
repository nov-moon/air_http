import 'dart:io';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/air_http.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/response.dart';

/// Gzip操作的processor
///
/// 主要用来添加Gzip的请求头，和解析Gzip的请求结果
class GzipProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) async {
    var request = node.request;
    var raw = request.raw;
    if (raw.isGzip == null) {
      raw.isGzip = AirHttp.isRequestGzip;
    }

    if (raw.isGzip ?? false) {
      raw.getHeaders().removeIgnoreCase("Content-Encoding");
      raw.addHeader("Content-Encoding", "gzip");
    }
    raw.getHeaders().removeIgnoreCase("Accept-Encoding");
    raw.addHeader("Accept-Encoding", "deflate");

    // 处理 param
    final response = await node.process(request);
    if (response.httpCode < 200 || response.httpCode >= 300) {
      var e = AirHttpException(code: response.httpCode.toString());
      var resp = AirRealResponse();
      resp.httpCode = response.httpCode;
      resp.headers = response.headers;
      e.response = resp;
      e.request = request.raw;
      throw e;
    }
    if (response.headers.containsKeyIgnoreCase('Content-Encoding')) {
      final value = response.headers.getValueIgnoreCase('Content-Encoding');
      if (value?.contains("gzip") ?? false) {
        response.bodyBytes = gzip.decode(response.bodyBytes);
      }
    }
    // 处理 resp
    return response;
  }
}
