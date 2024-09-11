import 'package:http/http.dart' as http;
import 'dart:convert';

class RecipeService {
  static const String baseUrl = 'http://127.0.0.1:8080/receipt';

  // Fetch all recipes
  static Future<List<dynamic>> fetchRecipes() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load recipes');
    }
  }

  // Fetch recipe details by id
  static Future<Map<String, dynamic>> fetchRecipeDetails(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/$id'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load recipe details');
    }
  }

  // Delete a recipe
  static Future<void> deleteRecipe(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete recipe');
    }
  }

  // Add a new recipe
  static Future<bool> addRecipe(String name, List<String> components) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'components': components}),
    );
    return response.statusCode == 200;
  }
}
