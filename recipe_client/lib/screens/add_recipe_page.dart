import 'package:flutter/material.dart';
import '../services/recipe_service.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _componentsController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addRecipe() async {
    setState(() {
      _isLoading = true;
    });

    final title = _titleController.text;
    final components = _componentsController.text.split(',').map((c) => c.trim()).toList();

    if (await RecipeService.addRecipe(title, components)) {
      Navigator.pop(context, true);
    } else {
      print('Error adding recipe');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipe')
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Recipe Title')),
            TextField(
              controller: _componentsController,
              decoration: const InputDecoration(
                  labelText: 'Components (comma separated)'),
              maxLines: 5,
            ),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _addRecipe, 
                    child: const Text('Add Recipe')),
          ],
        ),
      ),
    );
  }
}
