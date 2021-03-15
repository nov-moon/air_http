part of 'http.dart';

abstract class HttpProcessor {
  Future<AirRawResponse> process(ProcessorNode node);
}

abstract class ProcessorNode {
  AirRealRequest get request;

  Future<AirRawResponse> process(AirRealRequest request);
}

class _ProcessorNodeImpl extends ProcessorNode {
  List<HttpProcessor> processors;
  HttpProcessor currentProcessor;
  AirRealRequest request;
  int index;
  bool _hasProcess = false;

  _ProcessorNodeImpl(this.processors, this.index, this.request)
      : currentProcessor = processors[index];

  @override
  Future<AirRawResponse> process(AirRealRequest request) {
    if (_hasProcess) {
      assert(false, "The processor may be run multi times!");
    }
    _hasProcess = true;
    if (processors.length == index + 1) {
      return currentProcessor.process(this);
    }
    final next = _ProcessorNodeImpl(processors, index + 1, request);
    return currentProcessor.process(next);
  }

  @override
  String toString() {
    return 'ProcessorNodeImpl{currentProcessor: $currentProcessor, index: $index, processors: $processors}';
  }
}
