import 'dart:io';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';

class FirebaseMlService {
  Future<File> loadModel() async {
    final instance = FirebaseModelDownloader.instance;
    final model = await instance.getModel(
      "Food-Recognizer",
      FirebaseModelDownloadType.localModelUpdateInBackground,
      FirebaseModelDownloadConditions(
        iosAllowsCellularAccess: true,
        iosAllowsBackgroundDownloading: false,
        androidChargingRequired: false,
        androidWifiRequired: false,
        androidDeviceIdleRequired: false,
      ),
    );
    return model.file;
  }
}
