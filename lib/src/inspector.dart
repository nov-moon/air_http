import 'package:air_http/src/request.dart';
import 'package:air_http/src/response.dart';

abstract class Interceptor {
  Future<AirRequest> interceptRequest(AirRequest request) async => request;

  Future<AirResponse> interceptResponse(AirResponse response) async => response;
}
