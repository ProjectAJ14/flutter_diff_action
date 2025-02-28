import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';

/// Command to execute Flutter/Dart commands on changed files.
class ExecCommand extends Command<int> {
  /// Creates a new instance of [ExecCommand].
  ExecCommand({
    required Logger logger,
  }) : _logger = logger {
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
      );
  }

  @override
  String get description => 'Execute a command on changed Dart/Flutter files';

  @override
  String get name => 'exec';

  final Logger _logger;

  @override
  Future<int> run() async {
    if (!isFlutterProjectRoot()) {
      _logger.err(
        'Error: No pubspec.yaml file found. '
        'This command should be run from the root of your Flutter project.',
      );
      return 1;
    }

    if (argResults == null) {
      _logger.info('No arguments.\n$usage');
      return 1;
    }

    final args = argResults!;
    _logger.detail('Arguments: ${args.arguments.join(', ')}');

    final branch = Options.branch.parsedValue(args);
    final remote = Options.remote.parsedValue(args);

    _logger.detail('Using remote: $remote, branch: $branch');

    final extraArgs = args.rest;
    if (extraArgs.isEmpty) {
      _logger.err('No command specified.\n$usage');
      return 1;
    }

    final bool isTest = extraArgs.any((e) => e == 'test');
    _logger.info('Running: ${extraArgs.join(' ')}');

    final relativeBasePath = getRelativeBasePath(_logger);

    final modifiedFiles = getModifiedFiles(remote, branch, logger: _logger)
        .where(
          (file) => file.endsWith('.dart') && file.startsWith(relativeBasePath),
        )
        .toList();

    if (modifiedFiles.isEmpty) {
      _logger.info('No modified Dart files detected.');
      return 0;
    }

    _logger.info('Modified Dart files:');
    for (final file in modifiedFiles) {
      _logger.info('  - $file');
    }

    final files = <String>[];
    final testFiles = <String>{};

    for (final file in modifiedFiles) {
      final relativePath = file.withoutBasePath(relativeBasePath);
      final platformPath = relativePath.withPlatformPath();

      if (File(platformPath).existsSync()) {
        files.add(relativePath);
        if (!isTest) {
          continue;
        }

        if (relativePath.endsWith('_test.dart')) {
          testFiles.add(relativePath);
        } else {
          final testFile = calculateTestFile(relativePath);
          if (File(testFile).existsSync()) {
            testFiles.add(testFile);
            _logger.detail('Added test file: $testFile for $relativePath');
          } else {
            _logger.warn('No test file found for $relativePath. Skipping...');
          }
        }
      } else {
        _logger.warn('File does not exist: $platformPath. Skipping...');
      }
    }

    final fileList = isTest ? testFiles : files;
    if (fileList.isEmpty) {
      _logger.info('No files to process.');
      return 0;
    }

    _logger.detail('Processing ${fileList.length} files');
    runCommand([...extraArgs, ...fileList], logger: _logger);

    return 0;
  }
}
