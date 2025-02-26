import 'dart:io';

import 'package:dart_diff_cli/src/utils/common_utils.dart';
import 'package:mason_logger/mason_logger.dart';

String getGitRepoRoot() {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    print('Error getting git repo root: ${result.stderr}');
    exit(1);
  }
  final path = result.stdout.toString().trim();
  return path;
}

String getRelativeBasePath([Logger? logger]) {
  final basePath = Directory.current.path.withUnixPath();
  final repoRoot = getGitRepoRoot();
  final relativeBasePath = basePath.withoutBasePath(repoRoot);
  logger?.info('Running in current directory: $relativeBasePath \n'
      'Repository root: $repoRoot \n'
      'Relative base path: $relativeBasePath \n');
  return relativeBasePath;
}

List<String> getModifiedFiles(String remote, String branch) {
  if (!_isGitInstalled()) {
    print('Error: Git is not installed or not found in PATH.');
    exit(1);
  }
  if (!_isGitRepository()) {
    print('Error: Not a git repository.');
    exit(1);
  }
  runCommand(['git', 'fetch', remote, branch], output: false);
  final result = runCommand(
    [
      'git',
      'diff',
      '--name-only',
      '--diff-filter=ACMRT',
      '$remote/$branch',
    ],
    output: false,
  );
  return result.split('\n').map((e) => e.trim()).toList();
}

bool _isGitInstalled() {
  try {
    final result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

bool _isGitRepository() {
  final result = Process.runSync('git', ['rev-parse', '--is-inside-work-tree']);
  return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
}
