import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Gets the files changed between the current working tree and
/// [remote]/[branch], plus untracked files.
///
/// Deleted files are included, and a rename is reported as a deletion plus
/// an addition, so callers can tell when a file other files import is gone.
///
/// Paths are relative to, and limited to, the current directory, so this
/// works both at the repository root and inside a mono-repo package.
///
/// The diff is taken against the merge base, so commits that landed on
/// [remote]/[branch] after this branch was created are not reported.
///
/// Runs `git fetch` first unless [fetch] is false. Returns null, after
/// logging the error, when the files can't be determined.
List<String>? getModifiedFiles(
  String remote,
  String branch, {
  required Logger logger,
  bool fetch = true,
}) {
  if (_git(['rev-parse', '--is-inside-work-tree']).exitCode != 0) {
    logger.err('Error: Not a git repository.');
    return null;
  }

  final target = '$remote/$branch';

  if (fetch) {
    logger.detail('Fetching remote branch: $target');
    final result = _git(['fetch', remote, branch]);
    if (result.exitCode != 0) {
      logger.warn(
        'Could not fetch $target, using the local ref. ${result.stderr}',
      );
    }
  }

  const diffArgs = ['diff', '--name-only', '--no-renames', '--relative'];
  var diff = _git([...diffArgs, '--merge-base', target]);
  if (diff.exitCode != 0) {
    // No merge base, e.g. in a shallow clone: fall back to the branch tip.
    logger.detail('Merge base diff failed: ${diff.stderr}');
    diff = _git([...diffArgs, target]);
  }
  if (diff.exitCode != 0) {
    logger.err('Error running git diff against $target: ${diff.stderr}');
    return null;
  }

  final untracked = _git(['ls-files', '--others', '--exclude-standard']);

  final files = {
    ..._lines(diff.stdout),
    if (untracked.exitCode == 0) ..._lines(untracked.stdout),
  }.toList();
  logger.detail('Found ${files.length} modified files');
  return files;
}

ProcessResult _git(List<String> args) => Process.runSync('git', args);

Iterable<String> _lines(Object? output) => output
    .toString()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty);
