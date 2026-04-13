import 'dart:convert';
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:food_recognizer_app/env/env.dart';

class GeminiService {
  late final GenerativeModel model;

  final Map<String, Map<String, dynamic>> _nutritionCache = {};

  GeminiService() {
    final apiKey = Env.geminiApiKey;
    model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'Saya adalah mesin ahli gizi yang mengidentifikasi nutrisi makanan. '
        'Berikan estimasi: kalori, karbohidrat, lemak, serat, dan protein (satuan gram/kkal). '
        'Selalu berikan estimasi nilai numerik yang masuk akal. Output HARUS dalam format JSON.',
      ),
      generationConfig: GenerationConfig(
        temperature: 0.0,
        responseMimeType: 'application/json',
        responseSchema: Schema(
          SchemaType.object,
          requiredProperties: [
            "kalori",
            "karbohidrat",
            "lemak",
            "serat",
            "protein",
          ],
          properties: {
            "kalori": Schema(SchemaType.string),
            "karbohidrat": Schema(SchemaType.string),
            "lemak": Schema(SchemaType.string),
            "serat": Schema(SchemaType.string),
            "protein": Schema(SchemaType.string),
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> getNutritionInfo(String foodName) async {
    final normalizedFoodName = foodName.toLowerCase().trim();

    if (_nutritionCache.containsKey(normalizedFoodName)) {
      log('CACHE HIT: Mengambil data "$normalizedFoodName" dari memori.');
      return _nutritionCache[normalizedFoodName];
    }

    try {
      final prompt = 'Nama makanannya adalah $foodName.';
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.trim().isEmpty) {
        return null;
      }

      log('Gemini raw response: ${response.text}');

      final RegExp regex = RegExp(r'\{[\s\S]*\}');
      final match = regex.firstMatch(response.text!);

      if (match != null) {
        final jsonString = match.group(0)!;
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

        _nutritionCache[normalizedFoodName] = decoded;
        return decoded;
      }

      log('ERROR: Gagal menemukan format JSON di respons Gemini.');
      return null;
    } catch (e, stackTrace) {
      log('Gemini error for "$foodName"', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
