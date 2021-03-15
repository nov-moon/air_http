import 'package:air_http/src/http.dart';
import 'package:air_http/src/response.dart';

class CacheProcessor implements HttpProcessor {
  @override
  Future<AirRawResponse> process(ProcessorNode node) {
    var request = node.request;
    return node.process(request);
  }
}
