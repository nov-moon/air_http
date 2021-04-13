enum Method {
  HEAD,
  GET,
  POST,
  PUT,
  PATCH,
  DELETE,
}

extension MethodExtension on Method {
  String get name {
    switch (this) {
      case Method.HEAD:
        return 'HEAD';
      case Method.GET:
        return 'GET';
      case Method.POST:
        return 'POST';
      case Method.PUT:
        return 'PUT';
      case Method.PATCH:
        return 'PATCH';
      case Method.DELETE:
        return 'DELETE';
    }
  }
}
