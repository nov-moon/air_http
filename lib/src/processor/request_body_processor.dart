import 'dart:convert';
import 'dart:io';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/methods.dart';
import 'package:air_http/src/response.dart';
import 'package:http/http.dart';

import '../../air_http.dart';

/// 处理Post类型的Body
class RequestBodyProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) async {
    var request = node.request;
    var raw = request.raw;
    final method = request.method;
    if (method == Method.GET ||
        method == Method.HEAD ||
        method == Method.DELETE) {
      return node.process(request);
    }

    if (request.isFileRequest()) {
      var req = Request(request.method.name, raw.url.asUri);
      var uploadBody = raw.uploadBody;
      if (uploadBody is File) {
        req.bodyBytes = await uploadBody.readAsBytes();
      } else {
        if (uploadBody is! List<int>) {
          throw AirHttpException(
              message: 'upload body just supports List<int> or File types');
        }
        req.bodyBytes = uploadBody;
      }
      if (request.headers[HttpHeaders.contentTypeHeader]?.isEmpty ?? true) {
        request.headers.removeIgnoreCase(HttpHeaders.contentTypeHeader);
        request.headers[HttpHeaders.contentTypeHeader] =
            'application/octet-stream';
      }
      if (request.encoding != null) {
        req.encoding = request.encoding!;
      }
      request.httpRequest = req;
    } else if (request.isMultiFileRequest()) {
      var req = MultipartRequest(request.method.name, raw.url.asUri);

      var params = raw.getParams();

      for (var key in params.keys) {
        var value = params[key];
        MultipartFile? part;
        if (value is File) {
          part = await MultipartFile.fromPath(key, value.path);
        } else if (value is List<int> &&
            !key.startsWith(annotationFieldNormal)) {
          part = MultipartFile.fromBytes(key, value);
        } else if (value is AirMultiFilePart) {
          if (value.value is File) {
            part = await MultipartFile.fromPath(key, value.value.path);
          } else {
            part = MultipartFile.fromBytes(key, value.value as List<int>);
          }
        } else {
          String k = key;
          if (key.startsWith(annotationFieldNormal)) {
            k = key.substring(annotationFieldNormal.length);
          }
          req.fields[k] = value;
        }
        if (part != null) {
          req.files.add(part);
        }
      }
      request.httpRequest = req;
    } else if (request.headers.isContentJson) {
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
