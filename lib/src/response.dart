import 'dart:convert';

import 'package:http/http.dart';

import 'request.dart';

abstract class AirResponseParser {
  bool isSuccess(Map<String, dynamic> result, int requestType);

  int getStatusCode(Map<String, dynamic> result, int requestType);

  String getMessage(Map<String, dynamic> result, int requestType);

  dynamic getData(Map<String, dynamic> result, int requestType);
}

class AirDefaultParser implements AirResponseParser {
  @override
  getData(Map<String, dynamic> result, int requestType) {
    return result['data'] ?? {};
  }

  @override
  String getMessage(Map<String, dynamic> result, int requestType) {
    return result['message'] ?? 'No message.';
  }

  @override
  int getStatusCode(Map<String, dynamic> result, int requestType) {
    return result['statusCode'] ?? -1;
  }

  @override
  bool isSuccess(Map<String, dynamic> result, int requestType) {
    return result['success'] ?? false;
  }
}

abstract class AirResponse {
  Map<String, String> headers = {};
  int httpCode = 0;
  AirRequest? request;
  bool success = false;
  int statusCode = -1;
  String message = '';

  Map<String, dynamic> get dataMap;

  List<dynamic> get dataList;

  dynamic get dataRaw;

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

class AirRealResponse extends AirResponse {
  dynamic exception;
  dynamic exceptionStack;

  dynamic dataRaw = '';

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

class AirRawResponse {
  late Map<String, String> headers;
  late int httpCode;
  late List<int> bodyBytes;
  late Response rawResponse;

  String get body => utf8.decode(bodyBytes);

  AirRawResponse.fromResponse(Response resp) {
    headers = resp.headers;
    httpCode = resp.statusCode;
    bodyBytes = resp.bodyBytes;
    rawResponse = resp;
  }
}
