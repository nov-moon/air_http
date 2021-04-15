import 'dart:io';

import 'package:air_http/air_http.dart';
import 'package:http/http.dart';

/// 处理Post类型的Body
class RespBodyProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) async {
    var req = node.request.raw;
    AirRawResponse resp = await node.process(node.request);

    if (req is DownloadRequest && req.targetFile != null) {
      var targetFile = req.targetFile!;
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      targetFile.createSync();
      IOSink? sink;
      try {
        sink = targetFile.openWrite();
        await sink.addStream(resp.rawStreamedResponse.stream);
        sink.flush();
      } catch (e, s) {
        print('when write file occur some errors');
        print('error --> $e');
        print(s.toString());
        rethrow;
      } finally {
        sink?.close();
      }

      resp.resultFile = targetFile;
      resp.headers = resp.rawStreamedResponse.headers;
      resp.httpCode = resp.rawStreamedResponse.statusCode;
      resp.bodyBytes = [];
      return resp;
    }

    return AirRawResponse.fromResponse(
        await Response.fromStream(resp.rawStreamedResponse));
  }
}
