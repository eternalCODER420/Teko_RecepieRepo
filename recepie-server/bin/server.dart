import 'dart:io';
import 'package:shelf/shelf_io.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'routes.dart'; // Import the route handlers
import 'database.dart'; // Import the database functions

void main(List<String> args) async {
  // Load the correct SQLite dynamic library based on the platform
  loadSQLiteLibrary();

  // Set up the router
  final router = Router();
  configureRoutes(router);

  // Configure a pipeline that logs requests.
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // Start the server
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
