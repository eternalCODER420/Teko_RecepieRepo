import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'database.dart'; // Import the database helpers

void configureRoutes(Router router) {
  // Root handler
  router.get('/', _rootHandler);

  // Echo handler
  router.get('/echo/<message>', _echoHandler);

  // Recipe-related routes
  router.get('/receipt', _getReceiptsHandler);          // List all recipes
  router.get('/receipt/<id>', _getReceiptHandler);      // Get a single recipe by ID
  router.post('/receipt', _setReceiptHandler);          // Create a new recipe
  router.delete('/receipt/<id>', _deleteReceiptHandler); // Delete a recipe by ID
}

// Basic handler for root URL
Response _rootHandler(Request request) {
  return Response.ok('Hello, World!\n');
}

// Echo handler to return the message provided in the URL
Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

// Asynchronously add a new recipe with its components to the database
Future<Response> _setReceiptHandler(Request request) async {
  final payload = await request.readAsString();
  final jsonData = jsonDecode(payload);

  final String? name = jsonData['name'];
  final List<dynamic>? components = jsonData['components'];

  if (name == null || components == null || components.isEmpty) {
    return Response.badRequest(body: 'Missing or invalid recipe name or components.\n');
  }

  final db = openDatabase();

  try {
    final insertRecipeStmt = db.prepare('INSERT INTO recipe (name) VALUES (?)');
    insertRecipeStmt.execute([name]);

    final recipeId = db.lastInsertRowId;

    final insertComponentStmt = db.prepare(
      'INSERT INTO component (name, recipe_id) VALUES (?, ?)'
    );

    for (final component in components) {
      if (component is String && component.isNotEmpty) {
        insertComponentStmt.execute([component.trim(), recipeId]);
      }
    }

    insertRecipeStmt.dispose();
    insertComponentStmt.dispose();

    return Response.ok('Recipe "$name" with components saved.\n');
  } finally {
    closeDatabase(db);
  }
}

// Asynchronously fetch all recipes
Future<Response> _getReceiptsHandler(Request request) async {
  final db = openDatabase();

  try {
    final result = db.select('''
      SELECT r.id AS recipe_id, r.name AS recipe_name, 
             c.id AS component_id, c.name AS component_name
      FROM recipe r
      LEFT JOIN component c ON r.id = c.recipe_id
    ''');

    final Map<int, Map<String, dynamic>> recipesMap = {};

    for (final row in result) {
      final recipeId = row['recipe_id'];
      recipesMap.putIfAbsent(recipeId, () => {
        'id': recipeId,
        'name': row['recipe_name'],
        'components': []
      });

      if (row['component_id'] != null) {
        recipesMap[recipeId]!['components'].add({
          'id': row['component_id'],
          'name': row['component_name'],
        });
      }
    }

    final recipes = recipesMap.values.toList();
    final jsonResponse = jsonEncode(recipes);

    return Response.ok(jsonResponse, headers: {
      'Content-Type': 'application/json',
    });
  } finally {
    closeDatabase(db);
  }
}

// Asynchronously fetch a single recipe by its ID
Future<Response> _getReceiptHandler(Request request) async {
  final id = request.params['id'];
  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  final db = openDatabase();

  try {
    final result = db.select('''
      SELECT r.id AS recipe_id, r.name AS recipe_name, 
             c.id AS component_id, c.name AS component_name
      FROM recipe r
      LEFT JOIN component c ON r.id = c.recipe_id
      WHERE r.id = ?
    ''', [id]);

    if (result.isEmpty) {
      return Response.notFound('Recipe with ID $id not found.\n');
    }

    final Map<String, dynamic> recipe = {
      'id': result.first['recipe_id'],
      'name': result.first['recipe_name'],
      'components': []
    };

    for (final row in result) {
      if (row['component_id'] != null) {
        recipe['components'].add({
          'id': row['component_id'],
          'name': row['component_name'],
        });
      }
    }

    final jsonResponse = jsonEncode(recipe);

    return Response.ok(jsonResponse, headers: {
      'Content-Type': 'application/json',
    });
  } finally {
    closeDatabase(db);
  }
}

// Asynchronously delete a recipe by its ID
Future<Response> _deleteReceiptHandler(Request request) async {
  final id = request.params['id'];
  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  final db = openDatabase();

  try {
    final recipeResult = db.select('SELECT * FROM recipe WHERE id = ?', [id]);

    if (recipeResult.isEmpty) {
      return Response.notFound('Recipe with ID $id not found.\n');
    }

    db.execute('BEGIN TRANSACTION');
    db.execute('DELETE FROM component WHERE recipe_id = ?', [id]);
    db.execute('DELETE FROM recipe WHERE id = ?', [id]);
    db.execute('COMMIT');

    return Response.ok('Recipe with ID $id and its components were deleted.\n');
  } catch (e) {
    db.execute('ROLLBACK');
    return Response.internalServerError(body: 'Failed to delete recipe with ID $id.\n');
  } finally {
    closeDatabase(db);
  }
}
