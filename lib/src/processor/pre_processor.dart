import 'package:air_extensions/air_api.dart';
import 'package:air_http/src/exception.dart';
import 'package:air_http/src/http.dart';
import 'package:air_http/src/response.dart';

/// 预处理的Processor
///
/// 现在主要用来整理url、host、header
class PreProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) {
    var request = node.request;
    var raw = request.raw;

    // 处理Host
    if (!request.url.isPathHttp) {
      var host = raw.host ??= AirHttp.hostFactory?.call(raw.requestType);
      if (host?.isEmpty ?? true) {
        throw AirHttpException(message: 'The request dose not have host');
      }
      if (host != null && !host.endsWith('/')) {
        host += '/';
      }
      raw.host = host;
      request.url = host! + request.url;
    }

    // 处理pathParam
    raw.getPathParams().forEach((key, value) {
      request.url = request.url.replaceAll('@$key', value);
    });

    // 处理pathAppendParam
    raw.getPathAppends().forEach((value) {
      request.url = request.url + value;
    });

    // 处理通用header
    final baseHeader = AirHttp.headers?.call(raw.requestType ?? 0);
    baseHeader?.foreach((key, value) {
      if (!request.headers.containsKey(key)) {
        request.headers[key] = value;
      }
    });

    return node.process(request);
  }
}
