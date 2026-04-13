import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_recognizer_app/service/firebase_ml_service.dart';
import 'package:food_recognizer_app/service/food_classification_service.dart';
import 'package:food_recognizer_app/widget/camera_view.dart';
import 'package:food_recognizer_app/widget/classification_item.dart';

// Viewmodel sesuai pola silabus
class CameraStreamViewmodel extends ChangeNotifier {
  final FoodClassificationService _service;

  CameraStreamViewmodel(this._service) {
    _service.initHelper();
  }

  Map<String, double> _classifications = {};

  // Top 1 hasil klasifikasi
  Map<String, double> get classifications => Map.fromEntries(
    (_classifications.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(1),
  );

  Future<void> runClassification(CameraImage camera) async {
    _classifications = await _service.analyzeImageFromCamera(camera);
    notifyListeners();
  }

  Future<void> close() async {
    await _service.close();
  }
}

class CameraStreamPage extends StatelessWidget {
  const CameraStreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Scan Makanan'),
      ),
      body: MultiProvider(
        providers: [
          Provider(
            create: (context) => FoodClassificationService(FirebaseMlService()),
          ),
          ChangeNotifierProvider(
            create: (context) => CameraStreamViewmodel(
              context.read<FoodClassificationService>(),
            ),
          ),
        ],
        child: const _CameraStreamBody(),
      ),
    );
  }
}

class _CameraStreamBody extends StatefulWidget {
  const _CameraStreamBody();

  @override
  State<_CameraStreamBody> createState() => _CameraStreamBodyState();
}

class _CameraStreamBodyState extends State<_CameraStreamBody> {
  late final CameraStreamViewmodel readViewmodel;

  @override
  void initState() {
    super.initState();
    readViewmodel = context.read<CameraStreamViewmodel>();
  }

  @override
  void dispose() {
    Future.microtask(() async => await readViewmodel.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CameraView(
          onImage: (cameraImage) async {
            await readViewmodel.runClassification(cameraImage);
          },
        ),
        Positioned(
          bottom: 0,
          right: 0,
          left: 0,
          child: Container(
            color: Colors.white,
            child: SafeArea(
              bottom: true,
              child: Consumer<CameraStreamViewmodel>(
                builder: (_, viewmodel, __) {
                  final classifications = viewmodel.classifications.entries;
                  if (classifications.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: classifications
                          .map(
                            (c) => ClassificatioinItem(
                              item: c.key,
                              value: "${(c.value * 100).toStringAsFixed(1)}%",
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
