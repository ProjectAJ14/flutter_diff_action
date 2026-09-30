import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';

/// Command to execute Flutter/Dart commands on changed files.
///
class ExecCommand extends Command<int> {
  /// Creates a new instance of [ExecCommand].
  ///
  /// [maxCommandLength] caps the length of each command line; the changed
  /// files are split over several runs to stay under it. It defaults to what
  /// the platform shell allows.
  ExecCommand({
    required Logger logger,
    int? maxCommandLength,
  })  : _logger = logger,
        // runInShell goes through cmd.exe on Windows, which allows 8191
        // characters after expansion. flutter.bat re-expands the arguments
        // with its own paths, so leave it about 2000 characters.
        _maxCommandLength =
            maxCommandLength ?? (Platform.isWindows ? 6000 : 100000) {
    argParser
      ..addOption(
        Options.branch.name,
        abbr: Options.branch.abbr,
        defaultsTo: Options.branch.defaultVal,
        help: 'Specify the base branch to use for git diff',
      )
      ..addOption(
        Options.remote.name,
        abbr: Options.remote.abbr,
        defaultsTo: Options.remote.defaultVal,
        help: 'Specify the remote repository to use for git diff',
      )
      ..addFlag(
        'fetch',
        defaultsTo: true,
        help: 'Run git fetch for the base branch before the diff',
      );
  }

  @override
  String get description => 'Execute a command on changed Dart/Flutter files';

  @override
  String get name => 'exec';

  final Logger _logger;
  final int _maxCommandLength;

  @override
  Future<int> run() async {
    if (!isFlutterProjectRoot()) {
      _logger.err(
        'Error: No pubspec.yaml file found. '
        'This command should be run from the root of your Dart/Flutter project.',
      );
      return 1;
    }

    final args = argResults!;
    _logger.detail('Arguments: ${args.arguments.join(', ')}');

    final branch = Options.branch.parsedValue(args);
    final remote = Options.remote.parsedValue(args);

    _logger.detail('Using remote: $remote, branch: $branch');

    // They are passed to git as arguments, so they must not look like options.
    if (branch.startsWith('-') || remote.startsWith('-')) {
      _logger.err('Error: The branch and remote cannot start with "-".');
      return ExitCode.usage.code;
    }

    final extraArgs = args.rest;
    if (extraArgs.isEmpty) {
      _logger.err('No command specified.\n$usage');
      return 1;
    }

    final changedFiles = getModifiedFiles(
      remote,
      branch,
      logger: _logger,
      fetch: args.flag('fetch'),
    );
    if (changedFiles == null) return 1;

    final isTest = isTestCommand(extraArgs);
    if (isTest) {
      // A deleted source file can break the tests of the files importing it.
      final trigger = changedFiles
          .where(
            (file) =>
                affectsAllTests(file) ||
                (file.endsWith('.dart') &&
                    !file.endsWith('_test.dart') &&
                    !File(file).existsSync()),
          )
          .firstOrNull;
      if (trigger != null) {
        _logger.info('$trigger changed, running the full test suite.');
        return runCommand(extraArgs, logger: _logger);
      }
    }

    final modifiedFiles = changedFiles
        .where((file) => file.endsWith('.dart') && File(file).existsSync())
        .toList();

    if (modifiedFiles.isEmpty) {
      _logger.info('No modified Dart files detected.');
      return 0;
    }

    _logger.info('Modified Dart files[${modifiedFiles.length}]:');
    for (final file in modifiedFiles) {
      _logger.info('  - $file');
    }

    final fileList = <String>{};
    for (final file in modifiedFiles) {
      if (!isTest || file.endsWith('_test.dart')) {
        fileList.add(file);
      } else if (File(calculateTestFile(file)).existsSync()) {
        fileList.add(calculateTestFile(file));
      } else {
        _logger.detail('No test file found for $file. Skipping...');
      }
    }

    if (fileList.isEmpty) {
      _logger.info('No files to process.');
      return 0;
    }

    _logger.detail('Processing ${fileList.length} files');

    // Run every chunk, even after a failure, and report the first failure.
    var exitCode = 0;
    for (final command
        in chunkArgs(extraArgs, fileList.toList(), _maxCommandLength)) {
      final code = await runCommand(command, logger: _logger);
      if (exitCode == 0) exitCode = code;
    }
    return exitCode;
  }
}
