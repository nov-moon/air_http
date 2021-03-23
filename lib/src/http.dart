import 'dart:convert';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/processor/body_processor.dart';
import 'package:air_http/src/processor/cache_processor.dart';
import 'package:air_http/src/processor/gzip_processor.dart';
import 'package:air_http/src/processor/pre_processor.dart';
import 'package:air_http/src/processor/query_processor.dart';
import 'package:flutter/foundation.dart';

import 'inspector.dart';
import 'methods.dart';
import 'processor/emitter_processor.dart';
import 'request.dart';
import 'response.dart';

part 'processor.dart';

typedef InterceptorRequestType = Future<AirRequest> Function(
    AirRequest request);
typedef InterceptorResponseType = Future<AirResponse> Function(
    AirResponse response);

class AirHttp with _AirHttpMixin {
  /// 配置通用Host
  ///
  /// 你可以通过[requestType]参数判断当前请求类型，此参数是由[AirRequest.requestType]透传过来的
  static String Function(int? requestType)? hostFactory;

  /// 配置通用header
  static Map<String, dynamic> Function(int requestType)? headers;

  /// response解析器
  static Future<AirResponse> Function(AirRawResponse response, int requestType)
      responseParser = _defaultResponseParser;

  /// exception处理器
  static Function(dynamic exception)? onExceptionOccurred;

  /// 拦截request
  static set interceptRequest(InterceptorRequestType value) {
    _baseInterceptorWrap._baseInterceptRequest = value;
  }

  /// 拦截response
  static set interceptResponse(InterceptorResponseType value) {
    _baseInterceptorWrap._baseInterceptResponse = value;
  }

  /// 添加拦截器
  static void addInterceptor(Interceptor interceptor) {
    _interceptors.add(interceptor);
  }

  /// 删除拦截器
  static void removeInterceptor(Interceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  /// 管理请求处理配置
  static List<HttpProcessor> processors = [];

  /// 默认请求超时时间
  static int requestTimeout = 60 * 1000;

  /// 是否开启gzip
  static bool isRequestGzip = false;

  /// 是否每次网络请求都关闭client
  ///
  /// 默认为true，每次网络请求完成后，都会关闭Client。
  /// 如果设置为false，则在app退出时需要调用[closeClient]方法回收资源。
  // static bool isCloseClientEveryTime = true;

  /// 主动回收当前client。
  // static void closeClient() {
  //   _onAppStop();
  // }

  /// 是否打印log
  static set printLog(bool value) {
    _ApiLogRequest? logRequest = _interceptors.findFirstAs<_ApiLogRequest>();
    _ApiLogResponse? logResponse = _interceptors.findFirstAs<_ApiLogResponse>();
    if (value) {
      if (logResponse == null) {
        _interceptors.insert(0, _ApiLogResponse());
      }
      if (logRequest == null) {
        _interceptors.insert(0, _ApiLogRequest());
      }
    } else {
      if (logResponse != null) {
        _interceptors.remove(logResponse);
      }
      if (logRequest != null) {
        _interceptors.remove(logRequest);
      }
    }
  }

  static _BaseInterceptorWarp _baseInterceptorWrap = _BaseInterceptorWarp();

  static List<Interceptor> _interceptors = [
    _ApiLogRequest(),
    _ApiLogResponse(),
    _baseInterceptorWrap
  ];

  AirHttp._withRequest(AirRequest request) {
    _request = request;
  }

  static Future<AirResponse> _defaultResponseParser(
      AirRawResponse response, int requestType) async {
    final map = jsonDecode(response.body);
    final result = AirRealResponse();
    if (map == null) {
      return result;
    }
    result.success = map['success'] ?? false;
    result.statusCode = map['statusCode'] ?? -1;
    result.message = map['message'] ?? 'No message.';
    result.dataRaw = map['data'] ?? {};
    return result;
  }

// static void _onAppStop() {
//   print("_onAppStop_onAppStop");
//   try {
//     EmitterProcessor.httpClient?.close();
//   } catch (e) {
//     print(e);
//   }
//   EmitterProcessor.httpClient = null;
// }
}

mixin _AirHttpMixin {
  late AirRequest _request;

  /// Send a request by the 'POST' method.
  Future<AirResponse> post() async {
    final request = await _buildRequest(Method.POST);

    return _method(request);
  }

  /// Send a request by the 'GET' method.
  Future<AirResponse> get() async {
    final request = await _buildRequest(Method.GET);

    return _method(request);
  }

  /// Send a request by the 'HEAD' method.
  Future<AirResponse> head() async {
    final request = await _buildRequest(Method.HEAD);

    return _method(request);
  }

  /// Send a request by the 'PUT' method.
  Future<AirResponse> put() async {
    final request = await _buildRequest(Method.PUT);
    return _method(request);
  }

  /// Send a request by the 'PATCH' method.
  Future<AirResponse> patch() async {
    final request = await _buildRequest(Method.PATCH);
    return _method(request);
  }

  /// Send a request by the 'DELETE' method.
  Future<AirResponse> delete() async {
    final request = await _buildRequest(Method.DELETE);
    return _method(request);
  }

  Future<AirRequest> _buildRequest(Method method) async {
    _request.method = method;
    AirRequest request = _request;
    if (_request.host == null) {
      _request.host = AirHttp.hostFactory?.call(_request.requestType ?? 0);
    }

    for (var value in AirHttp._interceptors) {
      request = await value.interceptRequest(request);
    }

    for (var value in _request.getInterceptors()) {
      request = await value.interceptRequest(request);
    }
    return request;
  }

  Future<AirResponse> _method(AirRequest request) async {
    List<HttpProcessor> processors = [];
    processors.addAll(request.getProcessors());
    processors.addAll(AirHttp.processors);
    processors.add(PreProcessor());
    processors.add(CacheProcessor());
    processors.add(QueryProcessor());
    processors.add(BodyProcessor());
    processors.add(GzipProcessor());
    processors.add(EmitterProcessor());

    ProcessorNode node =
        _ProcessorNodeImpl(processors, 0, AirRealRequest(request));

    AirResponse csResponse =
        await node.process(node.request).then((response) async {
      // 正常请求的处理
      final result =
          await AirHttp.responseParser(response, request.requestType ?? 0);
      result.request = request;
      result.httpCode = response.httpCode;
      result.headers = response.headers;
      return result;
    }).catchError((exception, stack) async {
      // 发生错误时的处理
      AirResponse result = AirRealResponse();
      result.request = request;
      result.httpCode = -1;
      if (AirHttp.onExceptionOccurred != null) {
        dynamic processResult = AirHttp.onExceptionOccurred?.call(exception);
        if (processResult is Future) {
          processResult = await processResult;
        }
        if (processResult != null && processResult is AirResponse) {
          result = processResult;
        } else {
          result.message = processResult?.toString() ?? "";
        }
      } else {
        result.message = exception.toString();
      }
      if (result is AirRealResponse) {
        if (result.exception == null) result.exception = exception;
        if (result.exceptionStack == null) result.exceptionStack = stack;
      }
      return result;
    });

    for (var value in AirHttp._interceptors) {
      csResponse = await value.interceptResponse(csResponse);
    }

    for (var interceptor in request.getInterceptors()) {
      csResponse = await interceptor.interceptResponse(csResponse);
    }
    return csResponse;
  }
}

extension AirHttpExtension on String {
  AirRequest http([Map<String, dynamic>? params]) {
    final http = AirRequest.fromUrl(this, params);
    return http;
  }

  Future<AirResponse> httpPost([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).post();
  }

  Future<AirResponse> httpGet([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).get();
  }

  Future<AirResponse> httpPut([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).put();
  }

  Future<AirResponse> httpHead([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).head();
  }

  Future<AirResponse> httpDelete([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).delete();
  }

  Future<AirResponse> httpPatch([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).patch();
  }
}

mixin HttpMixin {
  AirRequest http(String url, [Map<String, dynamic>? params]) {
    final http = AirRequest.fromUrl(url, params);
    ontCreateRequest(http);
    return http;
  }

  @protected
  void ontCreateRequest(AirRequest request) {}

  @protected
  void ontResponseComplete(AirResponse response) {}

  Future<AirResponse> httpPost(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).post();
    ontResponseComplete(result);
    return result;
  }

  Future<AirResponse> httpGet(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).get();
    ontResponseComplete(result);
    return result;
  }

  Future<AirResponse> httpPut(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).put();
    ontResponseComplete(result);
    return result;
  }

  Future<AirResponse> httpHead(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).head();
    ontResponseComplete(result);
    return result;
  }

  Future<AirResponse> httpDelete(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).delete();
    ontResponseComplete(result);
    return result;
  }

  Future<AirResponse> httpPatch(String url,
      [Map<String, dynamic>? params]) async {
    AirRequest request = http(url, params);
    var result = await AirHttp._withRequest(request).patch();
    ontResponseComplete(result);
    return result;
  }
}

extension AirRequestExtension on AirRequest {
  Future<AirResponse> post() async {
    return AirHttp._withRequest(this).post();
  }

  Future<AirResponse> get() async {
    return AirHttp._withRequest(this).get();
  }

  Future<AirResponse> head() async {
    return AirHttp._withRequest(this).head();
  }

  Future<AirResponse> put() async {
    return AirHttp._withRequest(this).put();
  }

  Future<AirResponse> patch() async {
    return AirHttp._withRequest(this).patch();
  }

  Future<AirResponse> delete() async {
    return AirHttp._withRequest(this).delete();
  }
}

class _BaseInterceptorWarp extends Interceptor {
  InterceptorRequestType? _baseInterceptRequest;
  InterceptorResponseType? _baseInterceptResponse;

  _BaseInterceptorWarp();

  @override
  Future<AirRequest> interceptRequest(AirRequest request) {
    _baseInterceptRequest?.call(request);
    return super.interceptRequest(request);
  }

  Future<AirResponse> interceptResponse(AirResponse response) {
    _baseInterceptResponse?.call(response);
    return super.interceptResponse(response);
  }
}

class _ApiLogRequest extends Interceptor {
  @override
  Future<AirRequest> interceptRequest(AirRequest request) {
    assert(() {
      try {
        _print(request.toString());
      } catch (e, s) {
        print('++++++++++++++++++' + s.toString());
      }
      return true;
    }());

    return super.interceptRequest(request);
  }
}

class _ApiLogResponse extends Interceptor {
  //带有首行缩进的Json格式
  static JsonEncoder encoder = JsonEncoder.withIndent('  ');

  Future<AirResponse> interceptResponse(AirResponse response) async {
    assert(() {
      try {
        if (response is AirRealResponse) {
          final jsonResult = response.dataRaw.toString();
//          final jsonResult = encoder.convert(response.dataRaw);
          _print(response.toFormatString(jsonResult));
        } else {
          _print(response.toString());
        }
      } catch (e, s) {
        print('++++++++++++++++++' + s.toString());
      }
      return true;
    }());
    return super.interceptResponse(response);
  }
}

void _print(String message) {
  if (message.length > 12 * 1024) {
    print(message);
  } else {
    debugPrint(message);
  }
}
