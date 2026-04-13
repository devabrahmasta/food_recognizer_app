import 'dart:convert';
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:food_recognizer_app/env/env.dart';

class GeminiService {
  late final GenerativeModel model;

  GeminiService() {
    final apiKey = Env.geminiApiKey;
    model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'Saya adalah suatu mesin yang mampu mengidentifikasi nutrisi atau kandungan gizi pada makanan layaknya uji laboratorium makanan. '
        'Hal yang bisa diidentifikasi adalah kalori, karbohidrat, lemak, serat, dan protein pada makanan. '
        'Satuan dari indikator tersebut berupa gram. '
        'Selalu berikan estimasi nilai numerik yang masuk akal. Jangan pernah mengembalikan nilai kosong atau null.',
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
            "kalori": Schema(SchemaType.integer),
            "karbohidrat": Schema(SchemaType.integer),
            "lemak": Schema(SchemaType.integer),
            "serat": Schema(SchemaType.integer),
            "protein": Schema(SchemaType.integer),
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> getNutritionInfo(String foodName) async {
    try {
      final prompt = 'Nama makanannya adalah $foodName.';

      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.trim().isEmpty) {
        log('Gemini response text is null or empty for: $foodName');
        return null;
      }

      log('Gemini raw response: ${response.text}');

      String raw = response.text!.trim();
      if (raw.startsWith('```')) {
        raw = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      log('Gemini decoded is not a Map: $decoded');
      return null;
    } catch (e, stackTrace) {
      log('Gemini error for "$foodName"', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
