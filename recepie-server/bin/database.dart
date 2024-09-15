import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';
import 'dart:io';
import 'dart:ffi';

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

void loadSQLiteLibrary() {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, _openOnWindows);
  } else if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openOnLinux);
  } else {
    throw UnsupportedError('This platform is not supported');
  }
}

Database openDatabase() {
  return sqlite3.open('recipeDb.db');
}

void closeDatabase(Database db) {
  db.dispose();
}
