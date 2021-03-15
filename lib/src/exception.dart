class AirHttpException implements Exception {
  String message;
  String code;
  dynamic? raw;

  AirHttpException({this.code = '9999', this.message = 'unknown', this.raw});
}
