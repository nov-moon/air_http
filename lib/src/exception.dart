import 'package:air_http/air_http.dart';

class AirHttpException implements Exception {
  String message;
  String code;
  AirRequest? request;
  AirResponse? response;
  dynamic? rawException;
  dynamic? rawStack;

  AirHttpException({
    this.code = '9999',
    this.message = 'unknown',
  });
}
