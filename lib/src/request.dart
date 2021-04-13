import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/response.dart';
import 'package:http/http.dart';

import 'http.dart';
import 'inspector.dart';
import 'methods.dart';

/// 网络请求的发起对象
///
/// 主要是对网络请求进行各种定制。
class AirRequest {
  /// 当前请求的原始url，有可能不包含host等信息
  String url;

  /// 当前请求的host，可以为空
  String? host;

  /// 当前的请求类型，可以为null，用于[AirHttp.hostFactory]等，通用设置的判断
  int? requestType;

  /// 当前请求的超时时间
  int? requestTimeout;

  /// 是否开启gzip
  bool? isGzip;

  /// 当前请求是否使用的UI交互类型，0不使用。一般用于loading弹出、错误时toast等。
  int? uxType;

  /// 当前request的持有对象，可能为空
  dynamic? requestHolder;

  /// response 解析器
  AirResponseParser? parser;

  /// 是否抛出exception
  bool? isThrowException;

  /// 当前请求编码，一般不用设置
  Encoding? encoding;

  /// 当前请求的上传实体，支持File、List<int>两种格式，如果有此字段，则忽略params字段
  /// 此字段要求请求method为put或post，否则无效
  dynamic? uploadBody;

  /// 当前请求的method
  late Method method;

  late VoidCallback closer;

  Map<String, dynamic> _headers = {};
  Map<String, dynamic> _params = {};
  Map<String, dynamic> _pathParams = {};
  List<String> _pathAppendParams = [];
  List<Interceptor> _interceptors = [];
  List<HttpProcessor> _processors = [];

  AirRequest.fromUrl(this.url, Map<String, dynamic>? params)
      : _params = params ?? {};

  AirRequest(
      {required String url,
      this.host,
      this.requestType,
      this.requestTimeout,
      this.encoding,
      Map<String, dynamic>? headers,
      Map<String, dynamic>? params,
      List<Interceptor> interceptors = const []})
      : url = url,
        _headers = headers ?? {},
        _params = params?.copy() ?? {},
        _interceptors = interceptors;

  Map<String, dynamic> getHeaders() => _headers;

  Map<String, dynamic> getParams() => _params;

  Map<String, dynamic> getPathParams() => _pathParams;

  List<String> getPathAppends() => _pathAppendParams;

  List<Interceptor> getInterceptors() => _interceptors;

  List<HttpProcessor> getProcessors() => _processors;

  /// Add some Path Param in the url.
  ///
  /// The url must be defined like this: 'userInfo/@userId', and the [params]'s key will be 'userId'.
  /// After this method process, the url will become like this: 'userInfo/47258'.
  /// The full example is:
  /// ```dart
  ///   static _loginUrl = 'userInfo/@userId';
  ///   Future<AirResponse> getUserInfo(userId) async {
  ///     return _loginUrl.http().pathParams({'userId': userId}).get();
  ///   }
  /// ```
  AirRequest pathParams(Map<String, dynamic> params) {
    _pathParams.addAll(params);
    return this;
  }

  /// Add a Path Param in the url.
  ///
  /// The url must be defined like this: 'userInfo/@userId', and the key will be 'userId'.
  /// After this method process, the url will become like this: 'userInfo/47258'.
  /// The full example is:
  /// ```dart
  ///   static _loginUrl = 'userInfo/@userId';
  ///   Future<AirResponse> getUserInfo(userId) async {
  ///     return _loginUrl.http().pathParam('userId', userId).get();
  ///   }
  /// ```
  AirRequest pathParam(String key, dynamic value) {
    if (!url.contains('@')) {
      assert(
          false,
          "The Path Param must be defined start with the symbol '@', "
          "for example: 'login/@userid/', current url is $url");
      return this;
    }
    _pathParams[key] = value;
    return this;
  }

  /// Append a param to the end of url
  AirRequest pathAppends(param) {
    if (param == null) {
      return this;
    }
    _pathAppendParams.add(param.toString());
    return this;
  }

  /// Add a param to the request
  AirRequest param(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  /// Add some params to the request
  AirRequest params(Map<String, dynamic> params) {
    _params.addAll(params);
    return this;
  }

  /// Add a header to the request
  AirRequest addHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  /// Add some headers to the request
  AirRequest addHeaders(Map<String, dynamic> headers) {
    _headers.addAll(headers);
    return this;
  }

  /// Add a interceptor to request
  AirRequest addInterceptor(Interceptor interceptor) {
    _interceptors.add(interceptor);
    return this;
  }

  /// Add a processor to request
  AirRequest addProcessor(HttpProcessor processor) {
    _processors.add(processor);
    return this;
  }

  /// Customize some features to the request
  AirRequest setFeature({
    String? host,
    int requestType = 0,
    bool? gzip,
    Encoding? encoding,
    int? requestTimeout,
  }) {
    this.host = host;
    this.requestType = requestType;
    isGzip = gzip;
    this.encoding = encoding;
    this.requestTimeout = requestTimeout;
    return this;
  }

  @override
  String toString() {
//    curl $param -X $method "$url" -H "accept: application/json" -H "Content-Type: application/json" $authorizationHeader

    var printUrl = url;
    if (host != null && !printUrl.isPathHttp) {
      printUrl = host! + url;
    }
    return """AirRequest{
    method: $method, url: $printUrl
    requestType: $requestType, requestTimeout: $requestTimeout, isGzip: $isGzip, encoding: $encoding
    headers: $_headers
    params: $_params
}""";
  }
}

class DownloadRequest extends AirRequest {
  File? targetFile;

  DownloadRequest.fromUrl(String url,
      {Map<String, dynamic>? params, this.targetFile})
      : super.fromUrl(url, params);
}

class AirMultiFilePart {
  String? contentType;
  String? filename;
  String? fieldName;
  dynamic value;

  AirMultiFilePart(this.value,
      {this.fieldName, this.filename, this.contentType});
}

class AirRealRequest {
  AirRequest raw;
  Map<String, String> headers;
  dynamic? body;
  Encoding? encoding;
  String url;
  Method method;
  Client? httpClient;
  BaseRequest? httpRequest;

  AirRealRequest(this.raw)
      : headers = raw.getHeaders().toStringMap,
        encoding = raw.encoding,
        url = raw.url,
        method = raw.method {
    raw.closer = close;
  }

  bool isFileRequest() {
    return raw.uploadBody != null;
  }

  bool isMultiFileRequest() {
    for (var v in raw._params.values) {
      if (v is File || v is List<int> || v is AirMultiFilePart) {
        return true;
      }
    }
    return false;
  }

  void close() {
    httpClient?.close();
    httpClient = null;
  }
}
