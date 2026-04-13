import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:food_recognizer_app/service/firebase_ml_service.dart';
import 'package:food_recognizer_app/service/isolate_inference.dart';

class FoodClassificationService {
  final FirebaseMlService _mlService;
  late Interpreter interpreter;
  late List<String> labels;
  late Tensor inputTensor;
  late Tensor outputTensor;
  late IsolateInference isolateInference;

  FoodClassificationService(this._mlService);

  Future<void> initHelper() async {
    try {
      await _loadLabels();
      await _loadModel();
      isolateInference = IsolateInference();
      await isolateInference.start();
    } catch (e, stackTrace) {
      log(
        'Error during FoodClassificationService initialization',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    final modelFile = await _mlService.loadModel();
    final options = InterpreterOptions()
      ..useNnApiForAndroid = true
      ..useMetalDelegateForIOS = true;

    interpreter = Interpreter.fromFile(modelFile, options: options);
    inputTensor = interpreter.getInputTensors().first;
    outputTensor = interpreter.getOutputTensors().first;
    log('Interpreter loaded successfully');
  }

  Future<void> _loadLabels() async {
    final labelTxt = await rootBundle.loadString('assets/labels.txt');
    labels = labelTxt.split('\n');
  }

  Future<Map<String, double>> analyzeImage(String imagePath) async {
    try {
      var isolateModel = InferenceModel(
        imagePath,
        interpreter.address,
        labels,
        inputTensor.shape,
        outputTensor.shape,
      );

      ReceivePort responsePort = ReceivePort();
      isolateInference.sendPort.send(
        isolateModel..responsePort = responsePort.sendPort,
      );

      var results = await responsePort.first;
      return results as Map<String, double>;
    } catch (e, stackTrace) {
      log('Error during image analysis', error: e, stackTrace: stackTrace);
      return <String, double>{};
    }
  }

  Future<void> close() async {
    try {
      await isolateInference.close();
    } catch (e, stackTrace) {
      log('Error closing isolate', error: e, stackTrace: stackTrace);
    }
  }
}
