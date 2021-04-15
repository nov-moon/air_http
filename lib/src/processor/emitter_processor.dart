import 'dart:convert';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/air_http.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/request.dart';
import 'package:air_http/src/response.dart';
import 'package:http/http.dart';

/// 真正的请求发射位置
class EmitterProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) async {
    var request = node.request;
    final client = request.httpClient = new Client();
    print('air_http: send request');
    StreamedResponse responseRaw;
    try {
      if (request.httpRequest != null) {
        var req = request.httpRequest!;
        req.headers.addAll(request.headers);
        responseRaw = await client.send(req);
      } else {
        var req = Request(request.method.name, request.url.asUri);

        req.headers.addAll(request.headers);
        if (request.encoding != null) request.encoding = request.encoding;
        var body = request.body;
        if (body != null) {
          if (body is String) {
            req.body = body;
          } else if (body is List) {
            req.bodyBytes = body.cast<int>();
          } else if (body is Map) {
            req.bodyFields = body.cast<String, String>();
          } else {
            throw AirHttpException(message: 'Invalid request body "$body".');
          }
        }

        responseRaw = await client.send(req);
      }
    } finally {
      // request.close();
    }

    return AirRawResponse.fromResponseStream(responseRaw);
  }

  /// 以Get类型的方式发送请求
  Future<Response> gets(
      Future<Response> fun(Uri url, {Map<String, String>? headers}),
      AirRealRequest request) {
    return fun(request.url.asUri, headers: request.headers);
  }

  /// 以Post类方式发送请求
  Future<Response> posts(
      Future<Response> fun(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}),
      AirRealRequest request) {
    return fun(request.url.asUri,
        headers: request.headers,
        body: request.body,
        encoding: request.encoding);
  }
}
