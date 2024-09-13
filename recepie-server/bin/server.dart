import 'dart:io';
import 'dart:ffi';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';

// Helper function to open the SQLite database
Database _openDatabase() {
  return sqlite3.open('recipeDb.db');
}

// Helper function to safely close the database
void _closeDatabase(Database db) {
  if (!db.isClosed) {
    db.dispose();
  }
}

// Platform-specific dynamic library loaders
DynamicLibrary _openOnLinux() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}/sqlite3.so');
  return DynamicLibrary.open(libraryNextToScript.path);
}

DynamicLibrary _openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}/sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/echo/<message>', _echoHandler)
  ..get('/receipt', _getReceiptsHandler) // List all recipes
  ..get('/receipt/<id>', _getReceiptHandler) // Get a single recipe by ID
  ..post('/receipt', _setReceiptHandler) // Create a new recipe (POST)
  ..delete('/receipt/<id>', _deleteReceiptHandler); // Delete a recipe by ID

// A basic handler for the root URL, returning a simple "Hello, World!" response.
Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

// Echo handler that returns the message sent as a URL parameter
Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

// Asynchronously add a new recipe with its components to the database
Future<Response> _setReceiptHandler(Request request) async {
  // Parse the JSON body of the request (async because reading from the network can take time)
  final payload = await request.readAsString();
  final jsonData = jsonDecode(payload);

  final String? name = jsonData['name'];
  final List<dynamic>? components = jsonData['components'];

  // Check if required fields are present and valid
  if (name == null || components == null || components.isEmpty) {
    return Response.badRequest(body: 'Missing or invalid recipe name or components.\n');
  }

  // Open the SQLite database
  final db = _openDatabase();

  try {
    // Insert the recipe into the recipe table
    final insertRecipeStmt = db.prepare('INSERT INTO recipe (name) VALUES (?)');
    insertRecipeStmt.execute([name]);

    // Get the ID of the newly inserted recipe
    final recipeId = db.lastInsertRowId;

    // Insert each component into the component table
    final insertComponentStmt = db.prepare(
        'INSERT INTO component (name, recipe_id) VALUES (?, ?)');

    for (final component in components) {
      if (component is String && component.isNotEmpty) {
        insertComponentStmt.execute([component.trim(), recipeId]);
      }
    }

    // Clean up the prepared statements
    insertRecipeStmt.dispose();
    insertComponentStmt.dispose();

    return Response.ok('Recipe "$name" with components saved.\n');
  } finally {
    // Close the database connection
    _closeDatabase(db);
  }
}

// Asynchronously get a single recipe by its ID (Optimized)
Future<Response> _getReceiptHandler(Request request) async {
  final id = request.params['id'];

  // Check if the ID is provided
  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  // Open the SQLite database
  final db = _openDatabase();

  try {
    // Optimized query: Fetch the recipe and its components in one go using a LEFT JOIN
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

    // Build the response from the joined query result
    final Map<String, dynamic> recipe = {
      'id': result.first['recipe_id'],
      'name': result.first['recipe_name'],
      'components': [],
    };

    for (final row in result) {
      if (row['component_id'] != null) {
        recipe['components'].add({
          'id': row['component_id'],
          'name': row['component_name'],
        });
      }
    }

    // Convert the recipe to JSON
    final jsonResponse = jsonEncode(recipe);

    return Response.ok(jsonResponse, headers: {
      HttpHeaders.contentTypeHeader: 'application/json',
    });
  } finally {
    // Close the database connection
    _closeDatabase(db);
  }
}

// Asynchronously list all recipes (Optimized)
Future<Response> _getReceiptsHandler(Request request) async {
  // Open the SQLite database
  final db = _openDatabase();

  try {
    // Optimized query: Fetch all recipes and their components in one go
    final result = db.select('''
      SELECT r.id AS recipe_id, r.name AS recipe_name, 
             c.id AS component_id, c.name AS component_name
      FROM recipe r
      LEFT JOIN component c ON r.id = c.recipe_id
    ''');

    // Preparing to store recipes and their components
    final Map<int, Map<String, dynamic>> recipesMap = {};

    // Loop through each row and group components by recipe
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

    // Convert the map of recipes to a list
    final List<Map<String, dynamic>> recipes = recipesMap.values.toList();

    // Convert the recipes list to JSON
    final jsonResponse = jsonEncode(recipes);

    // Return the JSON response
    return Response.ok(jsonResponse, headers: {
      HttpHeaders.contentTypeHeader: 'application/json',
    });
  } finally {
    // Close the database connection
    _closeDatabase(db);
  }
}

// Asynchronously delete a recipe by its ID
Future<Response> _deleteReceiptHandler(Request request) async {
  final id = request.params['id'];

  // Check if the ID is provided
  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  // Open the SQLite database
  final db = _openDatabase();

  try {
    // Check if the recipe exists
    final recipeResult = db.select('SELECT * FROM recipe WHERE id = ?', [id]);

    if (recipeResult.isEmpty) {
      return Response.notFound('Recipe with ID $id not found.\n');
    }

    // Begin a transaction to ensure atomicity
    db.execute('BEGIN TRANSACTION');

    // Delete components associated with the recipe
    db.execute('DELETE FROM component WHERE recipe_id = ?', [id]);

    // Delete the recipe itself
    db.execute('DELETE FROM recipe WHERE id = ?', [id]);

    // Commit the transaction
    db.execute('COMMIT');

    return Response.ok('Recipe with ID $id and its components were deleted.\n');
  } catch (e) {
    // Rollback the transaction in case of an error
    db.execute('ROLLBACK');
    return Response.internalServerError(body: 'Failed to delete recipe with ID $id.\n');
  } finally {
    // Close the database connection
    _closeDatabase(db);
  }
}

// Main function to start the server
void main(List<String> args) async {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, _openOnWindows);
  } else if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openOnLinux);
  } else {
    throw UnsupportedError('This platform is not supported');
  }

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
