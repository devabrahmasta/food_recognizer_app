import 'dart:developer';
import 'dart:isolate';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceModel {
  String imagePath;
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
    this.outputShape,
  );
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
        final imagePath = isolateModel.imagePath;
        final inputShape = isolateModel.inputShape;

        final img = await image_lib.decodeImageFile(imagePath);
        if (img == null) {
          throw Exception("Failed to decode image at path: $imagePath");
        }

        image_lib.Image imageInput = image_lib.copyResize(
          img,
          width: inputShape[1],
          height: inputShape[2],
        );

        final address = isolateModel.interpreterAddress;
        Interpreter interpreter = Interpreter.fromAddress(address);

        // CEK TIPE MODEL SECARA DINAMIS UNTUK MENCEGAH NATIVE CRASH
        final inputType = interpreter.getInputTensor(0).type;
        final outputType = interpreter.getOutputTensor(0).type;

        // 1. SIAPKAN MATRIKS INPUT
        dynamic input;
        if (inputType == TensorType.float32) {
          input = [
            List.generate(
              imageInput.height,
              (y) => List.generate(imageInput.width, (x) {
                final pixel = imageInput.getPixel(x, y);
                return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
              }),
            ),
          ];
        } else {
          input = [
            List.generate(
              imageInput.height,
              (y) => List.generate(imageInput.width, (x) {
                final pixel = imageInput.getPixel(x, y);
                return [pixel.r, pixel.g, pixel.b];
              }),
            ),
          ];
        }

        // 2. SIAPKAN WADAH OUTPUT
        dynamic output;
        if (outputType == TensorType.float32) {
          output = [List<double>.filled(isolateModel.outputShape[1], 0.0)];
        } else {
          output = [List<int>.filled(isolateModel.outputShape[1], 0)];
        }

        // 3. EKSEKUSI
        interpreter.run(input, output);
        final result = output.first;

        // 4. HITUNG SKOR
        var classification = <String, double>{};

        if (outputType == TensorType.float32) {
          final resDouble = result as List<double>;
          double maxScore = resDouble.reduce((a, b) => a + b);
          if (maxScore > 0) {
            for (int i = 0; i < resDouble.length; i++) {
              if (resDouble[i] > 0) {
                classification[isolateModel.labels[i]] =
                    resDouble[i] / maxScore;
              }
            }
          }
        } else {
          final resInt = result as List<int>;
          int maxScore = resInt.reduce((a, b) => a + b);
          if (maxScore > 0) {
            for (int i = 0; i < resInt.length; i++) {
              if (resInt[i] > 0) {
                classification[isolateModel.labels[i]] = resInt[i] / maxScore;
              }
            }
          }
        }

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

  Future<void> close() async {
    _isolate.kill();
    _receivePort.close();
  }
}
