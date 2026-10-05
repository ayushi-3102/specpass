import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('runMediaPipeSegmentation')
external JSPromise<SegmentationResult?>? _runMediaPipeSegmentation(JSString base64Image);

extension type SegmentationResult(JSObject _) implements JSObject {
  external JSArray<JSNumber>? get confidences;
}

Future<List<double>?> getWebNeuralMask(Uint8List rawBytes) async {
  try {
    final base64Str = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
    final promise = _runMediaPipeSegmentation(base64Str.toJS);
    if (promise == null) return null;

    final jsObj = await promise.toDart;
    if (jsObj == null) return null;

    final confidencesJs = jsObj.confidences;
    if (confidencesJs == null) return null;

    final result = <double>[];
    for (int i = 0; i < confidencesJs.length; i++) {
      result.add(confidencesJs[i].toDartDouble);
    }
    return result;
  } catch (_) {
    return null;
  }
}

@JS('runImglyBackgroundRemoval')
external JSPromise<JSString?>? _runImglyBackgroundRemoval(JSString base64Image, JSString? targetBgHex);

Future<Uint8List?> getWebImglyCutout(Uint8List rawBytes, [String? targetBgHex]) async {
  try {
    final base64Str = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
    final promise = _runImglyBackgroundRemoval(base64Str.toJS, targetBgHex?.toJS);
    if (promise == null) return null;

    final jsStr = await promise.toDart;
    if (jsStr == null) return null;

    final dataUrl = jsStr.toDart;
    final commaIdx = dataUrl.indexOf(',');
    if (commaIdx == -1) return null;

    return base64Decode(dataUrl.substring(commaIdx + 1));
  } catch (_) {
    return null;
  }
}

