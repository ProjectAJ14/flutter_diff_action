import 'dart:io';

import 'package:dart_diff_cli/src/utils/common_utils.dart';
import 'package:mason_logger/mason_logger.dart';

/// Gets the root directory of the git repository.
String getGitRepoRoot({required Logger logger}) {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    logger.err('Error getting git repo root: ${result.stderr}');
    exit(1);
  }
  final path = result.stdout.toString().trim();
  logger.detail('Git repo root: $path');
  return path;
}

/// Gets the path relative to the git repository root.
///
/// Returns the path of the current directory relative to the git
/// repository root.
String getRelativeBasePath({required Logger logger}) {
  final basePath = Directory.current.path.withUnixPath();
  final repoRoot = getGitRepoRoot(logger: logger);
  final relativeBasePath = basePath.withoutBasePath(repoRoot);
  logger.detail('Current directory: $basePath\n'
      'Repository root: $repoRoot\n'
      'Relative base path: $relativeBasePath');
  return relativeBasePath;
}

/// Gets the list of modified files between current branch and target branch.
///
/// [remote] specifies the git remote (e.g., 'origin')
/// [branch] specifies the target branch (e.g., 'main')
///
/// Returns a list of modified file paths.
List<String> getModifiedFiles(
  String remote,
  String branch, {
  required Logger logger,
}) {
  if (!_isGitInstalled()) {
    logger.err('Error: Git is not installed or not found in PATH.');
    exit(1);
  }
  if (!_isGitRepository()) {
    logger.err('Error: Not a git repository.');
    exit(1);
  }

  logger.detail('Fetching remote branch: $remote/$branch');

  runCommand(
    ['git', 'fetch', remote, branch],
    logger: logger,
  );

  logger.detail('Getting modified files between HEAD and $remote/$branch');

  final result = runCommand(
    [
      'git',
      'diff',
      '--name-only',
      '--diff-filter=ACMRT',
      '$remote/$branch',
    ],
    logger: logger,
  );
  final files =
      result.split('\n').where((line) => line.trim().isNotEmpty).toList();
  logger.detail('Found ${files.length} modified files');
  return files;
}

/// Checks if git is installed on the system.
bool _isGitInstalled() {
  try {
    final result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

/// Checks if the current directory is part of a git repository.
bool _isGitRepository() {
  final result = Process.runSync('git', ['rev-parse', '--is-inside-work-tree']);
  return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
}
