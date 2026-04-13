import 'dart:io';
import 'dart:developer';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:food_recognizer_app/utils/image_utils.dart';

class InferenceModel {
  CameraImage? cameraImage;
  String? imagePath;
  int interpreterAddress;
  List<String> labels;
  List<int> inputShape;
  List<int> outputShape;
  late SendPort responsePort;

  InferenceModel(
    this.imagePath,
    this.interpreterAddress,
    this.labels,
    this.inputShape,
    this.outputShape, {
    this.cameraImage,
  });
}

class IsolateInference {
  static const String _debugName = "TFLITE_INFERENCE";
  final ReceivePort _receivePort = ReceivePort();
  late Isolate _isolate;
  late SendPort _sendPort;
  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: _debugName,
    );
    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final InferenceModel isolateModel in port) {
      try {
        final inputShape = isolateModel.inputShape;
        image_lib.Image? img;

        if (isolateModel.cameraImage != null) {
          img = ImageUtils.convertCameraImage(isolateModel.cameraImage!);
          if (img != null) {
            img = image_lib.copyResize(
              img,
              width: inputShape[1],
              height: inputShape[2],
            );
            if (Platform.isAndroid) {
              img = image_lib.copyRotate(img, angle: 90);
            }
          }
        } else if (isolateModel.imagePath != null) {
          img = await image_lib.decodeImageFile(isolateModel.imagePath!);
          if (img != null) {
            img = image_lib.copyResize(
              img,
              width: inputShape[1],
              height: inputShape[2],
            );
          }
        }

        if (img == null) {
          isolateModel.responsePort.send(<String, double>{});
          continue;
        }

        final imageMatrix = List.generate(
          img.height,
          (y) => List.generate(img!.width, (x) {
            final pixel = img!.getPixel(x, y);
            return [pixel.r, pixel.g, pixel.b];
          }),
        );

        final input = [imageMatrix];
        final output = [List<int>.filled(isolateModel.outputShape[1], 0)];
        final address = isolateModel.interpreterAddress;
        final result = _runInference(input, output, address);

        int maxScore = result.reduce((a, b) => a + b);
        final keys = isolateModel.labels;
        final values = result
            .map((e) => e.toDouble() / maxScore.toDouble())
            .toList();
        var classification = Map.fromIterables(keys, values);
        classification.removeWhere((key, value) => value == 0);

        var sortedEntries = classification.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        var top1 = Map.fromEntries(sortedEntries.take(1));

        isolateModel.responsePort.send(top1);
      } catch (e, stackTrace) {
        log(
          'Error in TFLite inference isolate',
          error: e,
          stackTrace: stackTrace,
          name: _debugName,
        );
        isolateModel.responsePort.send(<String, double>{});
      }
    }
  }

  static List<int> _runInference(
    List<List<List<List<num>>>> input,
    List<List<int>> output,
    int interpreterAddress,
  ) {
    Interpreter interpreter = Interpreter.fromAddress(interpreterAddress);
    interpreter.run(input, output);
    final result = output.first;
    return result;
  }

  Future<void> close() async {
    _isolate.kill();
    _receivePort.close();
  }
}
