import 'dart:convert';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/methods.dart';
import 'package:air_http/src/request.dart';
import 'package:air_http/src/response.dart';
import 'package:http/http.dart';

/// 真正的请求发射位置
class EmitterProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) async {
    var request = node.request;
    final client = request.httpClient = new Client();
    AirRawResponse response;
    Response rawResponse;
    print('air_http: send request');
    try {
      if (request.httpRequest != null) {
        var req = request.httpRequest!;
        req.headers.addAll(request.headers);
        var result = await client.send(req);
        rawResponse = await Response.fromStream(result);
      } else {
        switch (request.method) {
          case Method.GET:
            rawResponse = await gets(client.get, request);
            break;
          case Method.HEAD:
            rawResponse = await gets(client.head, request);
            break;
          case Method.DELETE:
            rawResponse = await gets(client.delete, request);
            break;
          case Method.POST:
            rawResponse = await posts(client.post, request);
            break;
          case Method.PUT:
            rawResponse = await posts(client.put, request);
            break;
          case Method.PATCH:
            rawResponse = await posts(client.patch, request);
            break;
        }
      }
    } finally {
      request.close();
    }

    // if (AirHttp.isCloseClientEveryTime) {
    //   client.close();
    // }

    response = AirRawResponse.fromResponse(rawResponse);
    return response;
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
