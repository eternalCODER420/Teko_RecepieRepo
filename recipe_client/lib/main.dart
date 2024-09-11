import 'package:flutter/material.dart';
import 'screens/recipe_list_page.dart';

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
