import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RecipeListPage(),
    );
  }
}

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  List<dynamic> _recipes = [];

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  // Fetch recipes from the server
  Future<void> _fetchRecipes() async {
    final url = Uri.parse('http://127.0.0.1:8080/receipt');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _recipes = jsonDecode(response.body);
        });
      } else {
        throw Exception('Failed to load recipes');
      }
    } catch (e) {
      print('Error fetching recipes: $e');
    }
  }

  // Fetch recipe details by its ID
  Future<Map<String, dynamic>> _fetchRecipeDetails(int id) async {
    final url = Uri.parse('http://127.0.0.1:8080/receipt/$id');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load recipe details');
      }
    } catch (e) {
      print('Error fetching recipe details: $e');
      return {};
    }
  }

  // Delete a recipe by its ID
  Future<void> _deleteRecipe(int id) async {
    final url = Uri.parse('http://127.0.0.1:8080/receipt/del/$id');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        setState(() {
          _recipes.removeWhere((recipe) => recipe['id'] == id);
        });
      } else {
        throw Exception('Failed to delete recipe');
      }
    } catch (e) {
      print('Error deleting recipe: $e');
    }
  }

  // Open a new screen to show the recipe details
  void _openRecipe(int id) async {
    final recipeDetails = await _fetchRecipeDetails(id);
    if (recipeDetails.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailsPage(recipe: recipeDetails),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
      ),
      body: _recipes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return ListTile(
                  title: Text(recipe['name']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Open button
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        onPressed: () {
                          _openRecipe(recipe['id']);
                        },
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteRecipe(recipe['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class RecipeDetailsPage extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailsPage({Key? key, required this.recipe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Components:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: recipe['components'].length,
                itemBuilder: (context, index) {
                  return Text('- ${recipe['components'][index]}');
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
