import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Executes a command and returns its output.
///
/// [command] is the command to run as a list of strings.
/// [output] determines whether to output command execution to console.
/// [logger] optional logger for output instead of print statements.
///
/// Returns the command's stdout as a string.
String runCommand(
  List<String> command, {
  bool output = true,
  Logger? logger,
}) {
  if (output) {
    logger?.info('Running: ${command.join(' ')}');
  }

  final result = Process.runSync(
    command.first,
    command.sublist(1),
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    final errorMsg = 'Error running ${command.first} ${result.stderr}';
    logger?.err(errorMsg);
    exit(1);
  }

  final stdoutStr = result.stdout.toString();
  if (output && stdoutStr.isNotEmpty) {
    if (logger != null) {
      logger.info(stdoutStr);
    } else {
      stdout.write(stdoutStr);
    }
  }

  return stdoutStr;
}

/// Checks if the current directory is a Flutter/Dart project root.
///
/// Returns true if pubspec.yaml exists in the current directory.
bool isFlutterProjectRoot() {
  return File('pubspec.yaml').existsSync();
}

/// Calculates the path to the test file corresponding to a given source file.
///
/// [filePath] is the path to the source file.
///
/// Returns the path to the corresponding test file.
String calculateTestFile(String filePath) {
  if (filePath.startsWith('lib/')) {
    return filePath
        .replaceFirst('lib/', 'test/')
        .replaceAll('.dart', '_test.dart');
  }
  return filePath.replaceAll('.dart', '_test.dart');
}

/// Extension methods for String to handle file paths.
extension StringExtension on String {
  /// Removes the base path from a string path.
  String withoutBasePath(String path) => replaceFirst(
        '${path.withUnixPath()}/',
        '',
      );

  /// Converts Windows path separators to Unix style.
  String withUnixPath() => replaceAll('\\', '/');

  /// Converts Unix path separators to Windows style.
  String withWindowsPath() => replaceAll('/', '\\');

  /// Converts path separators to the current platform's format.
  String withPlatformPath() => Platform.isWindows ? withWindowsPath() : this;
}
