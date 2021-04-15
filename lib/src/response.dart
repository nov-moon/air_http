import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

import 'request.dart';

abstract class AirResponseParser {
  bool isSuccess(int httpCode, Map<String, String> headers, AirRequest request,
      Map<String, dynamic> respBody, int requestType);

  String parseStatusCode(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> respBody, int requestType);

  String parseMessage(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> respBody, int requestType);

  dynamic parseData(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> respBody, int requestType);

  bool parseLoginExpired(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> respBody, int requestType);
}

class AirDefaultParser implements AirResponseParser {
  @override
  parseData(int httpCode, Map<String, String> headers, AirRequest request,
      Map<String, dynamic> result, int requestType) {
    return result['data'] ?? {};
  }

  @override
  String parseMessage(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> result, int requestType) {
    return result['message'] ?? 'No message.';
  }

  @override
  String parseStatusCode(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> result, int requestType) {
    return result['code'] ?? '';
  }

  @override
  bool isSuccess(int httpCode, Map<String, String> headers, AirRequest request,
      Map<String, dynamic> result, int requestType) {
    return result['success'] ?? false;
  }

  @override
  bool parseLoginExpired(int httpCode, Map<String, String> headers,
      AirRequest request, Map<String, dynamic> respBody, int requestType) {
    return respBody['code'] == '9999' && respBody['data']['reload'];
  }
}

abstract class AirResponse {
  Map<String, String> headers = {};
  int httpCode = 0;
  AirRequest? request;
  bool success = false;
  String message = '';
  bool isLoginExpired = false;

  dynamic? dataRaw;

  bool get failed => !success;
}

abstract class AirApiResponse extends AirResponse {
  String statusCode = '';

  Map<String, dynamic> get dataMap;

  List<dynamic> get dataList;

  dynamic operator [](Object key) {
    if (dataRaw is Map) {
      return dataMap[key];
    }
    assert(false, 'The current data is not a map! data = $dataRaw');
    return null;
  }

  void operator []=(String key, dynamic value) {
    if (dataRaw is Map) {
      dataMap[key] = value;
      return;
    }
    assert(false, 'The current data is not a map! data = $dataRaw');
  }

  @override
  String toString() {
    return """AirResponse{
    url: ${request?.url}
    success: $success, httpCode: $httpCode, statusCode: $statusCode, message: $message
    header: $headers
    data: $dataRaw
    }""";
  }
}

class AirRealResponse extends AirApiResponse with ExceptionResponseMixin {
  Map<String, dynamic> get dataMap => dataRaw as Map<String, dynamic>;

  List<dynamic> get dataList => dataRaw as List<dynamic>;

  @override
  String toString() {
    return """AirResponse{
    url: ${request?.url}
    success: $success, httpCode: $httpCode, statusCode: $statusCode, message: $message
    header: $headers
    data: $dataRaw
    }""";
  }

  String toFormatString(String data) {
    var result = """AirResponse{
  url: ${request?.host}${request?.url}
  success: $success, httpCode: $httpCode, statusCode: $statusCode, message: $message
  header: $headers
""";
    result += '  data:';
    for (var value in data.split("\n")) {
      result += "  " + value + "\n";
    }
    if (exception != null) {
      result += '  exception: ${exception.toString()}\n';
    }
    if (exceptionStack != null) {
      result += '  exceptionStack:\n';
      var list = exceptionStack.toString().split("\n");
      for (var value in list) {
        result += "    " + value + "\n";
      }
    }
    result += "}";
    return result;
  }
}

class DownloadResponse extends AirResponse with ExceptionResponseMixin {
  File get resultFile => dataRaw as File;

  List<int> get resultBytes => dataRaw as List<int>;

  @override
  String toString() {
    return """DownloadResponse{
    url: ${request?.url}
    success: $success, httpCode: $httpCode
    header: $headers
    data: $dataRaw
    }""";
  }

  String toFormatString(String data) {
    var result = """DownloadResponse{
  url: ${request?.host}${request?.url}
  success: $success, httpCode: $httpCode
  header: $headers
""";
    result += '  data:';
    for (var value in data.split("\n")) {
      result += "  " + value + "\n";
    }
    if (exception != null) {
      result += '  exception: ${exception.toString()}\n';
    }
    if (exceptionStack != null) {
      result += '  exceptionStack:\n';
      var list = exceptionStack.toString().split("\n");
      for (var value in list) {
        result += "    " + value + "\n";
      }
    }
    result += "}";
    return result;
  }
}

class AirRawResponse {
  late Map<String, String> headers;
  late int httpCode;
  late List<int> bodyBytes;
  late File resultFile;
  Response? rawResponse;
  late StreamedResponse rawStreamedResponse;

  String get body => utf8.decode(bodyBytes);

  AirRawResponse.fromResponse(Response resp) {
    headers = resp.headers;
    httpCode = resp.statusCode;
    bodyBytes = resp.bodyBytes;
    rawResponse = resp;
  }

  AirRawResponse.fromResponseStream(StreamedResponse resp) {
    rawStreamedResponse = resp;
  }
}

mixin ExceptionResponseMixin {
  dynamic exception;
  dynamic exceptionStack;

  void setException(e) {}
}
