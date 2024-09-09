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
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteRecipe(recipe['id']);
                    },
                  ),
                );
              },
            ),
    );
  }
}
