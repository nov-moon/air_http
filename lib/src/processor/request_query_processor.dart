import 'dart:io';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/methods.dart';
import 'package:air_http/src/request.dart';
import 'package:air_http/src/response.dart';

/// 对类Get型的请求做url的query的处理
class RequestQueryProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) {
    AirRealRequest request = node.request;
    var raw = request.raw;
    final method = request.method;

    // 如果不是类Get请求，则直接进行下一个
    if (method == Method.PUT ||
        method == Method.POST ||
        method == Method.PATCH) {
      return node.process(request);
    }

    // 拼装url
    var paramUrl = request.url;
    if (raw.getParams().isNotEmpty) {
      if (!paramUrl.contains('?')) {
        paramUrl += "?";
      }
      raw.getParams().forEach((key, value) {
        paramUrl += "$key=$value&";
      });
      paramUrl = paramUrl.substring(0, paramUrl.length);
    }
    request.url = paramUrl;
    var contentHeader = request.headers[HttpHeaders.contentTypeHeader];
    if ((contentHeader?.isNotEmpty ?? false) &&
        contentHeader!.toLowerCase() == 'application/json') {
      request.headers.removeIgnoreCase(HttpHeaders.contentTypeHeader);
    }
    return node.process(request);
  }
}
