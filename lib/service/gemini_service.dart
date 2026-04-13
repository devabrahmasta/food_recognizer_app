import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:food_recognizer_app/env/env.dart';

class GeminiService {
  late final GenerativeModel model;

  GeminiService() {
    final apiKey = Env.geminiApiKey;
    model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
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
    try {
      final prompt =
          """
      Saya adalah suatu mesin yang mampu mengidentifikasi nutrisi atau kandungan gizi pada makanan layaknya uji laboratorium makanan.
      Hal yang bisa diidentifikasi adalah kalori, karbohidrat, lemak, serat, dan protein pada makanan. Satuan dari indikator tersebut berupa gram.
      Nama makanannya adalah $foodName.
      """;

      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        return jsonDecode(response.text!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
