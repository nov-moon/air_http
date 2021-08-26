import 'dart:convert';
import 'dart:io';

import 'package:air_extensions/air_api.dart';
import 'package:air_http/air_http.dart';
import 'package:air_http/src/processor/cache_processor.dart';
import 'package:air_http/src/processor/gzip_processor.dart';
import 'package:air_http/src/processor/pre_processor.dart';
import 'package:flutter/foundation.dart';

import 'inspector.dart';
import 'methods.dart';
import 'processor/emitter_processor.dart';
import 'processor/request_body_processor.dart';
import 'processor/request_query_processor.dart';
import 'processor/resp_body_processor.dart';
import 'request.dart';
import 'response.dart';

part 'processor.dart';

typedef InterceptorRequestType = Future<AirRequest> Function(
    AirRequest request);
typedef InterceptorResponseType = Future<AirResponse> Function(
    AirResponse response);

typedef ResponseParserFactory = AirResponseParser Function(int requestType);

class AirHttp with _AirHttpMixin {
  static AirDefaultParser _defaultParser = AirDefaultParser();

  /// 配置通用Host
  ///
  /// 你可以通过[requestType]参数判断当前请求类型，此参数是由[AirRequest.requestType]透传过来的
  static String Function(int? requestType)? hostFactory;

  /// 配置通用header
  static Map<String, dynamic> Function(int requestType)? headers;

  /// response解析器
  static ResponseParserFactory responseParser = (type) => _defaultParser;

  /// exception处理器
  static Function(dynamic exception)? onExceptionOccurred;

  /// 配置Proxy {'http_proxy':'http://192.168.124.7:8888'}
  static Map<String, String>? proxyEnv;

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

  /// 当发生错误，或者请求失败，或者请求结果success=false时，是否抛出错误，默认不抛出。
  ///
  /// 如果抛出错误，则错误类型为：[AirHttpException]
  static bool isThrowException = false;

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
    _request.requestTimeout = requestTimeout;
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
  Future<AirApiResponse> post() async {
    final request = await _buildRequest(Method.POST);

    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the 'GET' method.
  Future<AirApiResponse> get() async {
    final request = await _buildRequest(Method.GET);

    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the 'HEAD' method.
  Future<AirApiResponse> head() async {
    final request = await _buildRequest(Method.HEAD);

    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the 'PUT' method.
  Future<AirApiResponse> put() async {
    final request = await _buildRequest(Method.PUT);
    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the 'PATCH' method.
  Future<AirApiResponse> patch() async {
    final request = await _buildRequest(Method.PATCH);
    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the 'DELETE' method.
  Future<AirApiResponse> delete() async {
    final request = await _buildRequest(Method.DELETE);
    return await _method(request) as AirApiResponse;
  }

  /// Send a request by the [method].
  Future<AirResponse> send(Method method) async {
    final request = await _buildRequest(method);
    return _method(request);
  }

  Future<AirRequest> _buildRequest(Method method) async {
    _request.method = method;
    AirRequest request = _request;
    if (_request.host == null) {
      _request.host = AirHttp.hostFactory?.call(_request.requestType ?? 0);
    }

    if (_request.isThrowException == null) {
      _request.isThrowException = AirHttp.isThrowException;
    }
    if (_request.uxType == null) {
      _request.uxType = 1;
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
    processors.add(RequestQueryProcessor());
    processors.add(RequestBodyProcessor());
    processors.add(GzipProcessor());
    processors.add(RespBodyProcessor());
    processors.add(EmitterProcessor());

    if (request.parser == null) {
      request.parser = AirHttp.responseParser(request.requestType ?? 0);
    }

    var rawReq = AirRealRequest(request);

    ProcessorNode node = _ProcessorNodeImpl(processors, 0, rawReq);

    AirResponse resultResp =
        await node.process(node.request).then((response) async {
      if (request is DownloadRequest) {
        return _defaultDownloadParser(response, request);
      }
      // 正常请求的处理
      final result = await _defaultResponseParser(response, request);
      result.request = request;
      result.httpCode = response.httpCode;
      result.headers = response.headers;
      return result;
    }).catchError((exception, stack) async {
      // 发生AirHttpException类型错误时的处理
      if (exception is AirHttpException) {
        return _processError(exception, stack, request);
      }
      // 发生其他类型错误时的处理

      return _processOtherError(exception, stack, request);
    });

    rawReq.close();

    for (var value in AirHttp._interceptors) {
      resultResp = await value.interceptResponse(resultResp);
    }

    for (var interceptor in request.getInterceptors()) {
      resultResp = await interceptor.interceptResponse(resultResp);
    }

    var isThrow = resultResp.request?.isThrowException ?? false;
    if (isThrow && !resultResp.success) {
      var msg = 'unknown';
      if (resultResp is AirApiResponse) {
        msg = resultResp.message;
      }
      var e = AirHttpException(message: msg);
      e.request = resultResp.request ?? request;
      e.response = resultResp;
      if (resultResp is AirRealResponse) {
        e.rawException = resultResp.exception;
        e.rawStack = resultResp.exceptionStack;
      }
      print('request error -> $e');
      throw e;
    }

    return resultResp;
  }

  Future<AirApiResponse> _defaultResponseParser(
      AirRawResponse response, AirRequest request) async {
    final map = jsonDecode(response.body);
    final result = AirRealResponse();
    if (map == null) {
      return result;
    }
    var requestType = request.requestType ?? 0;
    var parser = request.parser!;
    var httpCode = response.httpCode;
    var header = response.headers;
    result.success =
        parser.isSuccess(httpCode, header, request, map, requestType);
    result.statusCode =
        parser.parseStatusCode(httpCode, header, request, map, requestType);
    result.message =
        parser.parseMessage(httpCode, header, request, map, requestType);
    result.dataRaw =
        parser.parseData(httpCode, header, request, map, requestType);
    result.isLoginExpired =
        parser.parseLoginExpired(httpCode, header, request, map, requestType);
    return result;
  }

  AirResponse _defaultDownloadParser(
      AirRawResponse response, DownloadRequest request) {
    var resp = DownloadResponse();
    resp.httpCode = response.httpCode;
    resp.request = request;
    resp.headers = response.headers;
    resp.success = response.httpCode >= 200 && response.httpCode < 300;
    if (request.targetFile != null) {
      resp.dataRaw = response.resultFile;
    } else {
      resp.dataRaw = response.bodyBytes;
    }
    return resp;
  }

  AirResponse _processError(
      AirHttpException exception, dynamic stack, AirRequest request) {
    var resp = exception.response;
    if (resp == null) {
      if (request is DownloadRequest) {
        resp = DownloadResponse();
      } else {
        resp = AirRealResponse();
      }
      resp.request = request;
      resp.httpCode = -1;
    }
    if (resp is AirRealResponse) {
      resp.exception = exception;
      resp.exceptionStack = stack;
    } else if (resp is DownloadResponse) {
      resp.exception = exception;
      resp.exceptionStack = stack;
    }
    return resp;
  }

  Future<AirResponse> _processOtherError(
      dynamic exception, dynamic stack, AirRequest request) async {
    late AirResponse result;
    if (request is DownloadRequest) {
      result = DownloadResponse();
    } else {
      result = AirRealResponse();
    }
    result.request = request;
    result.httpCode = -1;
    if (AirHttp.onExceptionOccurred != null) {
      dynamic processResult = AirHttp.onExceptionOccurred?.call(exception);
      if (processResult is Future) {
        processResult = await processResult;
      }
      if (processResult != null && processResult is AirApiResponse) {
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
    if (result is AirRealResponse) {
      if (result.exception == null) result.exception = exception;
      if (result.exceptionStack == null) result.exceptionStack = stack;
    } else if (result is DownloadResponse) {
      if (result.exception == null) result.exception = exception;
      if (result.exceptionStack == null) result.exceptionStack = stack;
    }

    return result;
  }
}

extension AirHttpExtension on String {
  AirRequest http([Map<String, dynamic>? params]) {
    final http = AirRequest.fromUrl(this, params);
    return http;
  }

  Future<AirApiResponse> httpPost([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).post();
  }

  Future<AirApiResponse> httpGet([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).get();
  }

  Future<AirApiResponse> httpPut([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).put();
  }

  Future<AirApiResponse> httpHead([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).head();
  }

  Future<AirApiResponse> httpDelete([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).delete();
  }

  Future<AirApiResponse> httpPatch([Map<String, dynamic>? params]) {
    AirRequest request = http(params);
    return AirHttp._withRequest(request).patch();
  }
}

mixin HttpMixin {
  AirRequest http(String url, [Map<String, dynamic>? params]) {
    final http = AirRequest.fromUrl(url, params);
    return http;
  }

  @protected
  void onCreateRequest(AirRequest request) {}

  @protected
  void onResponseComplete(AirResponse response) {}

  Future<AirApiResponse> httpPost(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).post();
    onResponseComplete(result);
    return result;
  }

  /// 上传[uploadBody]对象，他可以是[File]、[List<int>]两种类型之一
  Future<AirApiResponse> httpUpload(String url, dynamic uploadBody,
      {int? uxType = 1,
      bool? isThrowException,
      Method method = Method.POST}) async {
    AirRequest request = http(url, null);
    request.uploadBody = uploadBody;
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result =
        await AirHttp._withRequest(request).send(method) as AirApiResponse;
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpMultipart(String url,
      {Map<String, dynamic>? params,
      required Map<String, dynamic> multipart,
      int? uxType = 1,
      bool? isThrowException}) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    request.isMultipart = true;
    request.addMultipartMap(multipart);
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).post();
    onResponseComplete(result);
    return result;
  }

  /// 下载
  Future<DownloadResponse> httpDownload(String url,
      {Map<String, dynamic>? params,
      File? resultFile,
      int? uxType = 1,
      bool? isThrowException,
      Method method = Method.GET}) async {
    var request =
        DownloadRequest.fromUrl(url, params: params, targetFile: resultFile);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result =
        await AirHttp._withRequest(request).send(method) as DownloadResponse;
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpGet(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException, int? requestType]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.requestType = requestType??0;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).get();
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpPut(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).put();
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpHead(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).head();
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpDelete(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).delete();
    onResponseComplete(result);
    return result;
  }

  Future<AirApiResponse> httpPatch(String url,
      [Map<String, dynamic>? params,
      int? uxType = 1,
      bool? isThrowException]) async {
    AirRequest request = http(url, params);
    request.uxType = uxType;
    request.isThrowException = isThrowException;
    request.requestHolder = this;
    onCreateRequest(request);
    var result = await AirHttp._withRequest(request).patch();
    onResponseComplete(result);
    return result;
  }
}

extension AirRequestExtension on AirRequest {
  Future<AirApiResponse> post() async {
    return AirHttp._withRequest(this).post();
  }

  Future<AirApiResponse> get() async {
    return AirHttp._withRequest(this).get();
  }

  Future<AirApiResponse> head() async {
    return AirHttp._withRequest(this).head();
  }

  Future<AirApiResponse> put() async {
    return AirHttp._withRequest(this).put();
  }

  Future<AirApiResponse> patch() async {
    return AirHttp._withRequest(this).patch();
  }

  Future<AirApiResponse> delete() async {
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
  // static JsonEncoder encoder = JsonEncoder.withIndent('  ');

  Future<AirResponse> interceptResponse(AirResponse response) async {
    assert(() {
      try {
        if (response is AirRealResponse) {
          // final jsonResult = response.dataRaw.toString();
//          final jsonResult = encoder.convert(response.dataRaw);
//           _print(response.toFormatString(jsonResult));
          assert(() {
            _print(_convert(response.dataMap, 1, isObject: true));
            return true;
          }());
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
  int maxLength = 900;
  if (message.length > maxLength) {
    while (message.length > maxLength) {
      String tempMessage = message.substring(0, maxLength);
      message = message.replaceFirst(tempMessage, '');
      print(tempMessage);
    }
    print(message);
  } else {
    debugPrint(message);
  }
}

/// [object]  解析的对象
/// [deep]  递归的深度，用来获取缩进的空白长度
/// [isObject] 用来区分当前map或list是不是来自某个字段，则不用显示缩进。单纯的map或list需要添加缩进
String _convert(dynamic object, int deep,
    {bool isObject = false, String name = ''}) {
  var buffer = StringBuffer();
  var nextDeep = deep + 1;
  if (object is Map) {
    var list = object.keys.toList();
    if (!isObject) {
      //如果map来自某个字段，则不需要显示缩进
      buffer.write("${getDeepSpace(deep)}");
    }
    buffer.write(name + "{");
    if (list.isEmpty) {
      //当map为空，直接返回‘}’
      buffer.write("}");
    } else {
      // buffer.write("\n");
      _print(buffer.toString());
      buffer.clear();
      for (int i = 0; i < list.length; i++) {
        // buffer.write("${getDeepSpace(nextDeep)}\"${list[i]}\":-");

        buffer.write(_convert(object[list[i]], nextDeep, name: '${list[i]}: '));
        if (i < list.length) {
          buffer.write(",");
          // buffer.write("\n");
          _print(buffer.toString());
          buffer.clear();
        }
      }
      // buffer.write("\n");
      buffer.clear();
      buffer.write("${getDeepSpace(deep)}}");
    }
  } else if (object is List) {
    if (!isObject) {
      //如果list来自某个字段，则不需要显示缩进
      buffer.write("${getDeepSpace(deep)}");
    }
    buffer.write("$name[");
    if (object.isEmpty) {
      //当list为空，直接返回‘]’
      buffer.write("]");
    } else {
      // buffer.write("\n");
      _print(buffer.toString());
      buffer.clear();
      for (int i = 0; i < object.length; i++) {
        buffer.write(_convert(object[i], nextDeep));
        if (i < object.length) {
          buffer.write(",");
          // buffer.write("\n");
          _print(buffer.toString());
          buffer.clear();
        }
      }
      // buffer.write("\n");
      buffer.clear();
      buffer.write("${getDeepSpace(deep)}]");
    }
  } else if (object is String) {
    buffer.write("${getDeepSpace(deep)}");
    //为字符串时，需要添加双引号并返回当前内容
    buffer.write("$name\"$object\"");
  } else if (object is num || object is bool) {
    buffer.write("${getDeepSpace(deep)}");
    //为数字或者布尔值时，返回当前内容
    buffer.write("$name$object");
  } else {
    buffer.write("${getDeepSpace(deep)}");
    //如果对象为空，则返回null字符串
    buffer.write("$name null");
  }
  return buffer.toString();
}

///获取缩进空白符
String getDeepSpace(int deep) {
  var tab = StringBuffer();
  for (int i = 0; i < deep; i++) {
    tab.write("  ");
  }
  return tab.toString();
}
