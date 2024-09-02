import 'dart:io';
import 'dart:ffi';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';

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
  ..get('/receipt', _getReceiptsHandler)
  // ..get('/receipt/set/<name>/<components>', _setReceiptHandler)
  ..post('/receipt', _setReceiptHandler)  // Changed to POST
  ..get('/receipt/<id>', _getReceiptHandler)
  ..delete('/receipt/<id>', _deleteReceiptHandler);

Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

Future<Response> _setReceiptHandler(Request request) async {
  // Parse the JSON body of the request
  // async because it can take a while to read from network, depending on how large body is
  final payload = await request.readAsString();
  final jsonData = jsonDecode(payload);

  //? -> allow null (dont cause exception), but process and respond to it below
  final String? name = jsonData['name'];
  final List<dynamic>? components = jsonData['components'];

  if (name == null || components == null || components.isEmpty) {
    return Response.badRequest(body: 'Missing or invalid recipe name or components.\n');
  }

  // Open the SQLite database
  final db = sqlite3.open('recipeDb.db');

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

  // Close the database connection
  db.dispose();

  return Response.ok('Recipe "$name" with components saved.\n');
}


Response _getReceiptHandler(Request request) {
  final id = request.params['id'];

  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  // Open the SQLite database
  final db = sqlite3.open('recipeDb.db');

  // Query to get the recipe by ID
  final recipeResult = db.select('SELECT * FROM recipe WHERE id = ?', [id]);

  if (recipeResult.isEmpty) {
    return Response.notFound('Recipe with ID $id not found.\n');
  }

  final recipeRow = recipeResult.first;

  // Query to get components for the current recipe
  final componentResult = db.select(
      'SELECT * FROM component WHERE recipe_id = ?', [id]);

  // Construct the recipe with its components
  final recipe = {
    'id': recipeRow['id'],
    'name': recipeRow['name'],
    'components': componentResult.map((componentRow) {
      return {
        'id': componentRow['id'],
        'name': componentRow['name'],
      };
    }).toList(),
  };

  // Close the database connection
  db.dispose();

  // Convert the recipe to JSON
  final jsonResponse = jsonEncode(recipe);

  return Response.ok(jsonResponse, headers: {
    HttpHeaders.contentTypeHeader: 'application/json',
  });
}

Response _getReceiptsHandler(Request request) {
  // Open the SQLite database
  final db = sqlite3.open('recipeDb.db');

  // Query to get all recipes
  final recipeResult = db.select('SELECT * FROM recipe');

  // Preparing to store recipes and their components
  final List<Map<String, dynamic>> recipes = [];

  // Loop through each recipe
  for (final recipeRow in recipeResult) {
    final recipeId = recipeRow['id'];

    // Query to get components for the current recipe
    final componentResult = db.select(
        'SELECT * FROM component WHERE recipe_id = ?', [recipeId]);

    // Constructing the recipe with its components
    final recipe = {
      'id': recipeId,
      'name': recipeRow['name'],
      'components': componentResult.map((componentRow) {
        return {
          'id': componentRow['id'],
          'name': componentRow['name'],
        };
      }).toList(),
    };

    // Add the recipe to the list
    recipes.add(recipe);
  }

  // Close the database connection
  db.dispose();

  // Convert the recipes list to JSON
  final jsonResponse = jsonEncode(recipes);

  // Return the JSON response
  return Response.ok(jsonResponse, headers: {
    HttpHeaders.contentTypeHeader: 'application/json',
  });
}

Response _deleteReceiptHandler(Request request) {
  final id = request.params['id'];

  if (id == null) {
    return Response.badRequest(body: 'Missing recipe ID.\n');
  }

  // Open the SQLite database
  final db = sqlite3.open('recipeDb.db');

  // Check if the recipe exists
  final recipeResult = db.select('SELECT * FROM recipe WHERE id = ?', [id]);

  if (recipeResult.isEmpty) {
    db.dispose();
    return Response.notFound('Recipe with ID $id not found.\n');
  }

  // Begin a transaction to ensure atomicity
  db.execute('BEGIN TRANSACTION');

  try {
    // Delete components associated with the recipe
    db.execute('DELETE FROM component WHERE recipe_id = ?', [id]);

    // Delete the recipe itself
    db.execute('DELETE FROM recipe WHERE id = ?', [id]);

    // Commit the transaction
    db.execute('COMMIT');

    // Close the database connection
    db.dispose();

    return Response.ok('Recipe with ID $id and its components were deleted.\n');
  } catch (e) {
    // Rollback the transaction in case of an error
    db.execute('ROLLBACK');

    // Close the database connection
    db.dispose();

    return Response.internalServerError(body: 'Failed to delete recipe with ID $id.\n');
  }
}


void main(List<String> args) async {
  // Override the dynamic library loader based on the platform explicitly, because it doesnt work automatically in our tests
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
