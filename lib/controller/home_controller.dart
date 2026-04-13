import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:food_recognizer_app/ui/result_page.dart';

class HomeController extends ChangeNotifier {
  String? _originalImagePath;
  String? _croppedImagePath;

  String? get imagePath => _croppedImagePath ?? _originalImagePath;
  bool get hasImage => _originalImagePath != null;

  final ImagePicker _picker = ImagePicker();

  Future<void> onPickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      _originalImagePath = pickedFile.path;
      _croppedImagePath = null; 
      notifyListeners();
      await _cropImage(_originalImagePath!);
    }
  }

  Future<void> cropCurrentImage() async {
    if (_originalImagePath != null) {
      await _cropImage(_originalImagePath!);
    }
  }

  Future<void> _cropImage(String path) async {
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      maxWidth: 400,
      maxHeight: 400,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Potong Makanan',
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
      ],
    );

    if (croppedFile != null) {
      _croppedImagePath = croppedFile.path;
      notifyListeners();
    }
  }

  void goToResultPage(BuildContext context) {
    if (imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih gambar makanan terlebih dahulu!")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(imagePath: imagePath!),
      ),
    );
  }
}