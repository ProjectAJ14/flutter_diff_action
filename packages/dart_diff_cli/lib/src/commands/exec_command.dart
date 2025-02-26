import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';

class ExecCommand extends Command<int> {
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
      )
      ..addFlag(
        'flutter',
        abbr: 'f',
        help: 'Run flutter test instead of dart test',
      );
  }

  @override
  String get description => 'A exec command that just prints one joke';

  @override
  String get name => 'exec';

  final Logger _logger;

  @override
  Future<int> run() async {
    if (!isFlutterProjectRoot()) {
      print(
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
    _logger.info('args: ${args.arguments.join(', ')}');

    final branch = Options.branch.parsedValue(args);
    final remote = Options.remote.parsedValue(args);

    final extraArgs = args.rest;
    if (extraArgs.isEmpty) {
      _logger.info('No extra args.\n$usage');
      return 1;
    }

    final bool isTest = extraArgs.any((e) => e == 'test');

    print('Running: ${extraArgs.join(' ')}');

    final relativeBasePath = getRelativeBasePath(_logger);

    final modifiedFiles = getModifiedFiles(remote, branch)
        .where(
          (file) => file.endsWith('.dart') && file.startsWith(relativeBasePath),
        )
        .toList();

    if (modifiedFiles.isEmpty) {
      print('No modified Dart files detected.');
      return 0;
    }

    print('Modified Dart files:\n${modifiedFiles.join('\n')}');

    final files = <String>[];
    final testFiles = <String>{};

    for (final file in modifiedFiles) {
      final relativePath = file.withoutBasePath(relativeBasePath);
      if (File(relativePath.withPlatformPath()).existsSync()) {
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
          } else {
            print('No test file found for $relativePath. Skipping...');
          }
        }
      } else {
        print('File with path: $relativePath does not exist. Skipping...');
      }
    }

    final fileList = isTest ? testFiles : files;
    runCommand([...extraArgs, ...fileList]);

    return 0;
  }
}
