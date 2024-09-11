import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_recipe_page.dart';
import 'recipe_details_page.dart';
import '../services/recipe_service.dart';  // Import the service to fetch/delete recipes

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

  Future<void> _fetchRecipes() async {
    final recipes = await RecipeService.fetchRecipes();
    setState(() {
      _recipes = recipes;
    });
  }

  Future<void> _deleteRecipe(int id) async {
    await RecipeService.deleteRecipe(id);
    setState(() {
      _recipes.removeWhere((recipe) => recipe['id'] == id);
    });
  }

  void _openRecipe(int id) async {
    final recipeDetails = await RecipeService.fetchRecipeDetails(id);
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
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        onPressed: () {
                          _openRecipe(recipe['id']);
                        },
                      ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRecipePage()),
          ).then((result) {
            if (result == true) {
              _fetchRecipes();
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
