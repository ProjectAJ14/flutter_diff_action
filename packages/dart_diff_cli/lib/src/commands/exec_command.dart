import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';

/// Command to execute Flutter/Dart commands on changed files.
///
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
      )
      ..addFlag(
        Flags.includeDependencyTests.name,
        abbr: Flags.includeDependencyTests.abbr,
        defaultsTo: false,
        help: 'Include tests for files that use changed dependencies',
      )
      ..addOption(
        Options.dependencyScanDepth.name,
        abbr: Options.dependencyScanDepth.abbr,
        defaultsTo: Options.dependencyScanDepth.defaultVal,
        help: 'Comma-separated list of directories to scan for dependency usage',
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
        'This command should be run from the root of your Dart/Flutter project.',
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
    final includeDependencyTests = Flags.includeDependencyTests.parsedValue(args);
    final dependencyScanDepth = Options.dependencyScanDepth.parsedValue(args);

    _logger.detail('Using remote: $remote, branch: $branch');

    final extraArgs = args.rest;
    if (extraArgs.isEmpty) {
      _logger.err('No command specified.\n$usage');
      return 1;
    }

    final bool isTest = extraArgs.any((e) => e == 'test');
    _logger.info('Running: ${extraArgs.join(' ')}');

    final relativeBasePath = getRelativeBasePath(logger: _logger);

    final allModifiedFiles = getModifiedFiles(remote, branch, logger: _logger);
    final modifiedFiles = allModifiedFiles
        .where(
          (file) => file.endsWith('.dart') && file.startsWith(relativeBasePath),
        )
        .toList();

    // Process dependency changes if enabled
    final Set<String> dependencyAffectedFiles = {};
    if (includeDependencyTests) {
      dependencyAffectedFiles.addAll(
        await _processDependencyChanges(
          allModifiedFiles,
          remote,
          branch,
          dependencyScanDepth,
          isTest,
        ),
      );
    }

    if (modifiedFiles.isEmpty && dependencyAffectedFiles.isEmpty) {
      _logger.info('No modified Dart files or dependency changes detected.');
      return 0;
    }

    _logger.info('Modified Dart files[${modifiedFiles.length}]:');
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
            _logger.detail('No test file found for $relativePath. Skipping...');
          }
        }
      } else {
        _logger.warn('File does not exist: $platformPath. Skipping...');
      }
    }

    // Combine regular files with dependency-affected files
    final Set<String> allFiles = {};
    if (isTest) {
      allFiles.addAll(testFiles);
    } else {
      allFiles.addAll(files);
    }
    allFiles.addAll(dependencyAffectedFiles);

    if (allFiles.isEmpty) {
      _logger.info('No files to process.');
      return 0;
    }

    final fileList = allFiles.toList();
    _logger.detail('Processing ${fileList.length} files');
    _logger.info('Files to process:');
    for (final file in fileList) {
      _logger.info('  - $file');
    }
    
    runCommand([...extraArgs, ...fileList], logger: _logger);

    return 0;
  }

  /// Processes dependency changes and returns affected files.
  Future<Set<String>> _processDependencyChanges(
    List<String> allModifiedFiles,
    String remote,
    String branch,
    String dependencyScanDepth,
    bool isTest,
  ) async {
    final Set<String> affectedFiles = {};
    
    try {
      // Find changed pubspec files
      final changedPubspecs = PubspecUtils.getChangedPubspecFiles(
        allModifiedFiles,
        logger: _logger,
      );
      
      if (changedPubspecs.isEmpty) {
        _logger.detail('No pubspec.yaml files changed');
        return affectedFiles;
      }
      
      // Process each changed pubspec file
      for (final pubspecPath in changedPubspecs) {
        final packageRoot = pubspecPath.replaceAll('/pubspec.yaml', '');
        if (packageRoot.isEmpty) {
          // Root pubspec
          await _processPackageDependencyChanges(
            pubspecPath,
            '.',
            remote,
            branch,
            dependencyScanDepth,
            isTest,
            affectedFiles,
          );
        } else {
          // Package pubspec
          await _processPackageDependencyChanges(
            pubspecPath,
            packageRoot,
            remote,
            branch,
            dependencyScanDepth,
            isTest,
            affectedFiles,
          );
        }
      }
      
    } catch (e) {
      _logger.warn('Error processing dependency changes: $e');
    }
    
    return affectedFiles;
  }

  /// Processes dependency changes for a specific package.
  Future<void> _processPackageDependencyChanges(
    String pubspecPath,
    String packageRoot,
    String remote,
    String branch,
    String dependencyScanDepth,
    bool isTest,
    Set<String> affectedFiles,
  ) async {
    try {
      // Parse current pubspec
      final currentPubspec = PubspecUtils.parsePubspec(pubspecPath, logger: _logger);
      if (currentPubspec == null) {
        _logger.warn('Could not parse current pubspec: $pubspecPath');
        return;
      }
      
      // Get previous pubspec from git
      final previousPubspecContent = PubspecUtils.getPubspecFromRevision(
        pubspecPath,
        '$remote/$branch',
        logger: _logger,
      );
      
      if (previousPubspecContent == null) {
        _logger.detail('No previous version of pubspec found: $pubspecPath');
        return;
      }
      
      final previousPubspec = Pubspec.parse(previousPubspecContent);
      
      // Compare dependencies
      final changes = PubspecUtils.compareDependencies(
        currentPubspec,
        previousPubspec,
        logger: _logger,
      );
      
      if (!changes.hasChanges) {
        _logger.detail('No dependency changes in $pubspecPath');
        return;
      }
      
      _logger.info('Dependency changes detected in $pubspecPath:');
      for (final change in [...changes.added, ...changes.removed, ...changes.modified]) {
        _logger.info('  - $change');
      }
      
      // Find files affected by these dependency changes
      final searchPaths = dependencyScanDepth.split(',').map((p) => p.trim()).toList();
      final packageAffectedFiles = DependencyAnalyzer.getAffectedFiles(
        changes.allChangedDependencies,
        packageRoot,
        includeTests: isTest,
        logger: _logger,
      );
      
      _logger.info('Found ${packageAffectedFiles.length} files affected by dependency changes in $packageRoot');
      affectedFiles.addAll(packageAffectedFiles);
      
    } catch (e) {
      _logger.warn('Error processing package dependency changes for $pubspecPath: $e');
    }
  }
}
