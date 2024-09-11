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
  
  // Navigate to the add recipe page
  void _navigateToAddRecipe(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRecipePage()),
    );

    // After adding, refresh the recipe list if a new recipe was added
    if (result == true) {
      _fetchRecipes();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddRecipe(context),
        child: const Icon(Icons.add),
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

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _componentsController = TextEditingController();
  bool _isLoading = false;

  // Function to send POST request to add a new recipe
  Future<void> _addRecipe() async {
    setState(() {
      _isLoading = true;
    });

    final title = _titleController.text;
    final components = _componentsController.text;

    final url = Uri.parse('http://127.0.0.1:8080/receipt');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': title,
          'components': components.split(',').map((c) => c.trim()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true); // Return to main list and refresh
      } else {
        throw Exception('Failed to add recipe');
      }
    } catch (e) {
      print('Error adding recipe: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _componentsController,
              decoration: const InputDecoration(
                labelText: 'Components (comma separated)',
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _addRecipe,
                    child: const Text('Add Recipe'),
                  ),
          ],
        ),
      ),
    );
  }
}
