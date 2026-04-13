import 'dart:convert';
import 'package:http/http.dart' as http;

class MealDbService {
  Future<Map<String, dynamic>?> searchMealByName(String foodName) async {
    try {
      final url = Uri.parse(
        'https://www.themealdb.com/api/json/v1/1/search.php?s=$foodName',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['meals'] != null && (data['meals'] as List).isNotEmpty) {
          return data['meals'][0];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
