import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// A changed file. [path] is relative to the current directory and starts
/// with `../` when the file is outside it; [repoPath] is relative to the
/// repository root.
typedef ChangedFile = ({String path, String repoPath});

/// Gets the files changed between the current working tree and [base], plus
/// untracked files, across the whole repository.
///
/// Deleted files are included, and a rename is reported as a deletion plus
/// an addition, so callers can tell when a file other files import is gone.
///
/// The diff is taken against the merge base, so commits that landed on
/// [base] after this branch was created are not reported. When a shallow
/// clone doesn't reach the merge base, more history is fetched; when there
/// is still none, the diff is against [base] itself, with a warning.
///
/// Runs `git fetch <fetch>` first unless [fetch] is null. Returns null,
/// after logging the error, when the files can't be determined.
List<ChangedFile>? getModifiedFiles(
  String base, {
  required Logger logger,
  List<String>? fetch,
  void Function(String message)? warn,
}) {
  warn ??= logger.warn;
  final prefix = repoPrefix();
  if (prefix == null) {
    logger.err('Error: Not a git repository.');
    return null;
  }

  if (fetch != null) {
    logger.detail('Fetching: git fetch ${fetch.join(' ')}');
    final result = _git(['fetch', ...fetch]);
    if (result.exitCode != 0) {
      warn('Could not fetch $base, using the local ref. '
          '${result.stderr.toString().trim()}');
    }
  }

  if (_revParse('$base^{commit}') == null) {
    logger.err('Error: $base is not a known commit.');
    return null;
  }

  var mergeBase = _mergeBase(base);
  // A shallow clone may not reach the merge base yet. A pull request's merge
  // commit needs only 1: its first parent is the base.
  for (final depth in const [1, 100, 1000]) {
    if (mergeBase != null ||
        fetch == null ||
        _git(['rev-parse', '--is-shallow-repository'])
                .stdout
                .toString()
                .trim() !=
            'true') {
      break;
    }
    logger.detail('No merge base with $base, deepening the history by $depth');
    // Deepen the base and HEAD one at a time: in one fetch, git deepens
    // only one of them.
    _git(['fetch', '--deepen=$depth', ...fetch]);
    _git(['fetch', '--deepen=$depth', fetch.first, _revParse('HEAD')!]);
    mergeBase = _mergeBase(base);
  }
  if (mergeBase == null) {
    warn('No merge base with $base, so the changes are taken against $base '
        'itself and include what changed on it since this branch started. '
        'Check out the full history, e.g. with fetch-depth: 0.');
  } else if (mergeBase == _revParse('HEAD')) {
    warn('HEAD is already part of $base, so only uncommitted changes count.');
  }

  final diff = _git(['diff', '--name-only', '--no-renames', mergeBase ?? base]);
  if (diff.exitCode != 0) {
    logger.err('Error running git diff against $base: ${diff.stderr}');
    return null;
  }
  final untracked = _git(
    ['ls-files', '--others', '--exclude-standard', '--full-name', ':/'],
  );

  final up = '../' * '/'.allMatches(prefix).length;
  final files = [
    for (final repoPath in {
      ..._lines(diff.stdout),
      if (untracked.exitCode == 0) ..._lines(untracked.stdout),
    })
      (
        path: repoPath.startsWith(prefix)
            ? repoPath.substring(prefix.length)
            : '$up$repoPath',
        repoPath: repoPath,
      ),
  ];
  logger.detail('Found ${files.length} changed files');
  return files;
}

/// The current directory relative to the repository root, with a trailing
/// `/` (empty at the root), or null outside a git repository.
String? repoPrefix() {
  final result = _git(['rev-parse', '--show-prefix']);
  return result.exitCode == 0 ? result.stdout.toString().trim() : null;
}

/// The tracked and untracked Dart files under the current directory,
/// relative to it.
List<String> listDartFiles() => _lines(
      _git([
        'ls-files',
        '--cached',
        '--others',
        '--exclude-standard',
        '--',
        '*.dart',
      ]).stdout,
    ).where((file) => File(file).existsSync()).toSet().toList()
      ..sort();

String? _mergeBase(String base) {
  final result = _git(['merge-base', base, 'HEAD']);
  return result.exitCode == 0 ? result.stdout.toString().trim() : null;
}

String? _revParse(String arg) {
  final result = _git(['rev-parse', '--verify', '--quiet', arg]);
  return result.exitCode == 0 ? result.stdout.toString().trim() : null;
}

// quotePath=false keeps non-ASCII paths as they are instead of octal escapes.
ProcessResult _git(List<String> args) =>
    Process.runSync('git', ['-c', 'core.quotePath=false', ...args]);

Iterable<String> _lines(Object? output) => output
    .toString()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty);
