import 'dart:convert';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/methods.dart';
import 'package:air_http/src/response.dart';

/// 处理Post类型的Body
class BodyProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) {
    var request = node.request;
    var raw = request.raw;
    final method = request.method;
    if (method == Method.GET ||
        method == Method.HEAD ||
        method == Method.DELETE) {
      return node.process(request);
    }

    if (request.headers.isContentJson) {
      request.body = jsonEncode(raw.getParams());
    } else {
      request.body = raw.getParams().toStringMap;
    }

    return node.process(request);
  }
}

extension on Map<String, dynamic> {
  bool get isContentJson =>
      this['Content-Type'] != null &&
      this['Content-Type'].toString().toLowerCase() == "application/json";
}
