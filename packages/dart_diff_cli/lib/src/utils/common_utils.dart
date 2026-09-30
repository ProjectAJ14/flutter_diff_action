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

/// How `exec` picks what to pass to the command.
enum Mode {
  /// Pass the tests that depend on the changed files.
  test,

  /// Pass the changed Dart files.
  files,

  /// Run the command without files when the package, or a file it
  /// depends on, changed.
  package,
}

/// Picks the [Mode] for [command]: [Mode.test] for `flutter test`,
/// `dart test` or `fvm flutter test`, [Mode.package] for `analyze` (it must
/// see the files using the changed ones), [Mode.files] otherwise.
Mode detectMode(List<String> command) {
  bool runs(String subcommand) {
    final i = command.indexOf(subcommand);
    return i == 1 || (i == 2 && const ['flutter', 'dart'].contains(command[1]));
  }

  if (runs('test')) return Mode.test;
  if (runs('analyze')) return Mode.package;
  return Mode.files;
}

/// Whether a change to [file] can break tests without any test importing
/// it, so the whole suite must run.
///
/// That is: dependency, test, build or localization config,
/// `flutter_test_config.dart`, non-Dart files under `test/` (fixtures,
/// goldens), and non-Dart files under `lib/` or `assets/`.
bool affectsAllTests(String file) {
  return const [
        'pubspec.yaml',
        'pubspec.lock',
        'pubspec_overrides.yaml',
        'dart_test.yaml',
        'build.yaml',
        'l10n.yaml',
      ].contains(file) ||
      file.endsWith('flutter_test_config.dart') ||
      ((file.startsWith('test/') ||
              file.startsWith('lib/') ||
              file.startsWith('assets/')) &&
          !file.endsWith('.dart'));
}

/// Whether [file], a path relative to the package, is workspace-wide
/// config in a parent directory: the root `pubspec.yaml`, `pubspec.lock`
/// (shared by a pub workspace), `melos.yaml` or `analysis_options.yaml`.
bool affectsWorkspace(String file) => RegExp(
      r'^(\.\./)+(pubspec\.yaml|pubspec\.lock|pubspec_overrides\.yaml|'
      r'melos\.yaml|analysis_options\.yaml)$',
    ).hasMatch(file);

/// Turns a glob into a [RegExp] matching whole paths: `*` and `?` stay
/// within a directory, `**` crosses directories and `**/` matches zero or
/// more of them.
RegExp globToRegExp(String glob) {
  final pattern = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    if (glob.startsWith('**/', i)) {
      pattern.write('(.*/)?');
      i += 2;
    } else if (glob.startsWith('**', i)) {
      pattern.write('.*');
      i++;
    } else if (glob[i] == '*') {
      pattern.write('[^/]*');
    } else if (glob[i] == '?') {
      pattern.write('[^/]');
    } else {
      pattern.write(RegExp.escape(glob[i]));
    }
  }
  return RegExp('$pattern\$');
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
