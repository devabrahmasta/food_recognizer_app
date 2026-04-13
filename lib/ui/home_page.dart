import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_recognizer_app/controller/home_controller.dart';
import 'package:food_recognizer_app/ui/camera_stream_page.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Food Recognizer App'),
      ),
      body: const SafeArea(
        child: Padding(padding: EdgeInsets.all(16.0), child: _HomeBody()),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: controller.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(controller.imagePath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 100, color: Colors.grey),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Baris 1: Kamera & Galeri
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => context.read<HomeController>().onPickImage(
                  ImageSource.camera,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt),
                    SizedBox(width: 8),
                    Text("Kamera"),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => context.read<HomeController>().onPickImage(
                  ImageSource.gallery,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 8),
                    Text("Galeri"),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Baris 2: Scan Realtime
        FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraStreamPage(),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner),
              SizedBox(width: 8),
              Text("Scan Realtime"),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (controller.hasImage)
          Column(
            children: [
              FilledButton(
                onPressed: () =>
                    context.read<HomeController>().goToResultPage(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Text("Analyze")],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () =>
                    context.read<HomeController>().cropCurrentImage(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.crop),
                    SizedBox(width: 8),
                    Text("Crop Ulang"),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}