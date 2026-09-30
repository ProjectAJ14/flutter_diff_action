import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Runs [command], streaming its output to this process's stdout/stderr.
///
/// Returns the command's exit code.
Future<int> runCommand(
  List<String> command, {
  required Logger logger,
}) async {
  logger.info('Running: ${command.join(' ')}');

  final process = await Process.start(
    command.first,
    command.sublist(1),
    mode: ProcessStartMode.inheritStdio,
    // `flutter` and `dart` are .bat wrappers on Windows.
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}

/// Checks if the current directory is a Flutter/Dart project root.
///
/// Returns true if pubspec.yaml exists in the current directory.
bool isFlutterProjectRoot() {
  return File('pubspec.yaml').existsSync();
}

/// Calculates the path to the test file corresponding to a given source file.
///
/// `lib/src/foo.dart` maps to `test/src/foo_test.dart`; files outside `lib/`
/// map to a `_test.dart` sibling.
String calculateTestFile(String filePath) {
  final testPath = filePath.startsWith('lib/')
      ? filePath.replaceFirst('lib/', 'test/')
      : filePath;
  return '${testPath.substring(0, testPath.length - '.dart'.length)}'
      '_test.dart';
}

/// Whether [command] runs tests, e.g. `flutter test`, `dart test` or
/// `fvm flutter test`. `dart analyze test` is not a test command.
bool isTestCommand(List<String> command) {
  final i = command.indexOf('test');
  return i == 1 || (i == 2 && const ['flutter', 'dart'].contains(command[1]));
}

/// Whether a change to [file] can break tests that the file-to-test mapping
/// of [calculateTestFile] would not pick, so the whole suite must run.
///
/// That is: dependency, test, build or localization config, test helpers,
/// fixtures and goldens, and non-Dart files under `lib/` or `assets/`.
bool affectsAllTests(String file) {
  return const [
        'pubspec.yaml',
        'pubspec.lock',
        'dart_test.yaml',
        'build.yaml',
        'l10n.yaml',
      ].contains(file) ||
      (file.startsWith('test/') && !file.endsWith('_test.dart')) ||
      ((file.startsWith('lib/') || file.startsWith('assets/')) &&
          !file.endsWith('.dart'));
}

/// Splits [files] into commands that start with [base], so that each
/// command, joined by spaces, is at most [maxLength] characters long.
///
/// A file that doesn't fit on its own still gets a command of its own.
List<List<String>> chunkArgs(
  List<String> base,
  List<String> files,
  int maxLength,
) {
  final commands = <List<String>>[];
  var command = [...base];
  var length = base.join(' ').length;
  for (final file in files) {
    if (command.length > base.length && length + 1 + file.length > maxLength) {
      commands.add(command);
      command = [...base];
      length = base.join(' ').length;
    }
    command.add(file);
    length += 1 + file.length;
  }
  return [...commands, command];
}
