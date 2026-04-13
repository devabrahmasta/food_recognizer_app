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
  bool _isLoadingMealDb = false;
  bool _isLoadingGemini = false;

  String _foodName = "Menganalisis...";
  String _confidenceScore = "";
  bool _isUnrecognized = false;

  Map<String, dynamic>? _recipeData;
  Map<String, dynamic>? _nutritionData;

  bool? _mealDbStatus;
  bool? _geminiStatus;

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

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _foodName = "Gagal menganalisis";
          _isLoadingML = false;
          _isUnrecognized = true;
        });
        return;
      }

      final topResult = results.entries.first;
      final confidence = topResult.value;

      if (confidence <= 0.40) {
        setState(() {
          _foodName = "Bukan makanan / Tidak Dikenali";
          _confidenceScore = "${(confidence * 100).toStringAsFixed(2)}%";
          _isLoadingML = false;
          _isUnrecognized = true;
        });
        return;
      }

      setState(() {
        _foodName = topResult.key;
        _confidenceScore = "${(confidence * 100).toStringAsFixed(2)}%";
        _isLoadingML = false;
        _isLoadingMealDb = true;
        _isLoadingGemini = true;
      });

      final mealFuture = _mealDbService.searchMealByName(_foodName).then((data) {
        if (!mounted) return;
        setState(() {
          _recipeData = data;
          _mealDbStatus = data != null;
          _isLoadingMealDb = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _mealDbStatus = false;
          _isLoadingMealDb = false;
        });
      });

      final geminiFuture = _geminiService.getNutritionInfo(_foodName).then((data) {
        if (!mounted) return;
        setState(() {
          _nutritionData = data;
          _geminiStatus = data != null;
          _isLoadingGemini = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _geminiStatus = false;
          _isLoadingGemini = false;
        });
      });

      await Future.wait([mealFuture, geminiFuture]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _foodName = "Gagal menganalisis";
        _isLoadingML = false;
        _isLoadingMealDb = false;
        _isLoadingGemini = false;
        _isUnrecognized = true;
      });
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
          if (!_isLoadingML && !_isUnrecognized) ...[
            _buildNutritionSection(),
            const SizedBox(height: 8),
            _buildRecipeSection(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionSection() {
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
            if (_isLoadingGemini)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_geminiStatus == false || _nutritionData == null)
              _buildErrorInfo(
                icon: Icons.info_outline,
                message: "Informasi nilai gizi tidak tersedia untuk makanan ini.",
              )
            else ...[
              _buildNutritionRow("Kalori", _nutritionData!['kalori']),
              _buildNutritionRow("Karbohidrat", _nutritionData!['karbohidrat']),
              _buildNutritionRow("Lemak", _nutritionData!['lemak']),
              _buildNutritionRow("Serat", _nutritionData!['serat']),
              _buildNutritionRow("Protein", _nutritionData!['protein']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _buildRecipeSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Resep Makanan",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            if (_isLoadingMealDb)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mealDbStatus == false || _recipeData == null)
              _buildErrorInfo(
                icon: Icons.restaurant_menu,
                message: "Resep tidak ditemukan untuk makanan ini.",
              )
            else ...[
              Text(
                _recipeData!['strMeal'] ?? '-',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Foto makanan dari MealDB
              if (_recipeData!['strMealThumb'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _recipeData!['strMealThumb'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),

              const Text(
                "Bahan-bahan:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...List.generate(20, (index) {
                final i = index + 1;
                final ingredient = _recipeData!['strIngredient$i'];
                final measure = _recipeData!['strMeasure$i'];
                if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text("• $ingredient (${measure?.toString().trim() ?? ''})"),
                  );
                }
                return const SizedBox();
              }),
              const SizedBox(height: 12),

              const Text(
                "Instruksi:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(_recipeData!['strInstructions'] ?? '-'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorInfo({required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}