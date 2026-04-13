import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_recognizer_app/widget/classification_item.dart';
import 'package:food_recognizer_app/service/firebase_ml_service.dart';
import 'package:food_recognizer_app/service/food_classification_service.dart';
import 'package:food_recognizer_app/service/meal_db_service.dart';
import 'package:food_recognizer_app/service/gemini_service.dart';

class ResultPage extends StatelessWidget {
  final String imagePath;

  const ResultPage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Result Page'),
      ),
      body: SafeArea(child: _ResultBody(imagePath: imagePath)),
    );
  }
}

class _ResultBody extends StatefulWidget {
  final String imagePath;
  const _ResultBody({required this.imagePath});

  @override
  State<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends State<_ResultBody> {
  late FoodClassificationService _mlService;
  final MealDbService _mealDbService = MealDbService();
  final GeminiService _geminiService = GeminiService();

  bool _isLoadingML = true;
  bool _isLoadingAPI = true;

  String _foodName = "Menganalisis...";
  String _confidenceScore = "";

  Map<String, dynamic>? _recipeData;
  Map<String, dynamic>? _nutritionData;

  @override
  void initState() {
    super.initState();
    _mlService = FoodClassificationService(FirebaseMlService());
    _runInferenceAndFetchData();
  }

  Future<void> _runInferenceAndFetchData() async {
    try {
      await _mlService.initHelper();
      final results = await _mlService.analyzeImage(widget.imagePath);

      if (results.isNotEmpty) {
        final topResult = results.entries.first;
        final confidence = topResult.value;

        if (confidence <= 0.40) {
          if (mounted) {
            setState(() {
              _foodName = "Bukan makanan / Tidak Dikenali";
              _confidenceScore = "${(confidence * 100).toStringAsFixed(2)}%";
              _isLoadingML = false;
              _isLoadingAPI = false;
            });
          }
          return; 
        }

        if (mounted) {
          setState(() {
            _foodName = topResult.key;
            _confidenceScore = "${(confidence * 100).toStringAsFixed(2)}%";
            _isLoadingML = false;
          });
        }

        final mealFuture = _mealDbService.searchMealByName(_foodName);
        final geminiFuture = _geminiService.getNutritionInfo(_foodName);

        final responses = await Future.wait([mealFuture, geminiFuture]);

        if (mounted) {
          setState(() {
            _recipeData = responses[0];
            _nutritionData = responses[1];
            _isLoadingAPI = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foodName = "Gagal menganalisis";
          _isLoadingML = false;
          _isLoadingAPI = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mlService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.file(File(widget.imagePath), height: 300, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _isLoadingML
                ? const ClassificatioinItemShimmer()
                : ClassificatioinItem(item: _foodName, value: _confidenceScore),
          ),
          if (!_isLoadingML) ...[
            if (_isLoadingAPI)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildNutritionSection(),
              _buildRecipeSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionSection() {
    if (_nutritionData == null) return const SizedBox();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Informasi Nilai Gizi",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            Text("Kalori: ${_nutritionData!['kalori'] ?? '-'}"),
            Text("Karbohidrat: ${_nutritionData!['karbohidrat'] ?? '-'}"),
            Text("Lemak: ${_nutritionData!['lemak'] ?? '-'}"),
            Text("Serat: ${_nutritionData!['serat'] ?? '-'}"),
            Text("Protein: ${_nutritionData!['protein'] ?? '-'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeSection() {
    if (_recipeData == null) return const SizedBox();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Resep ${_recipeData!['strMeal']}",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const Text(
              "Bahan-bahan:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            ...List.generate(20, (index) {
              final i = index + 1;
              final ingredient = _recipeData!['strIngredient$i'];
              final measure = _recipeData!['strMeasure$i'];
              if (ingredient != null &&
                  ingredient.toString().trim().isNotEmpty) {
                return Text("- $ingredient ($measure)");
              }
              return const SizedBox();
            }),
            const SizedBox(height: 8),
            const Text(
              "Instruksi:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(_recipeData!['strInstructions'] ?? '-'),
          ],
        ),
      ),
    );
  }
}
