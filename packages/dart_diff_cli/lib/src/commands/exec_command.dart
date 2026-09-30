import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';

/// What a run does: `none`, `partial` (on [files]) or `full` (on
/// everything), and why.
typedef _Plan = ({String ran, String reason, List<String> files});

_Plan _none(String reason) => (ran: 'none', reason: reason, files: const []);
_Plan _full(String reason) => (ran: 'full', reason: reason, files: const []);

/// Command to execute Flutter/Dart commands on changed files.
///
class ExecCommand extends Command<int> {
  /// Creates a new instance of [ExecCommand].
  ///
  /// [maxCommandLength] caps the length of each command line; the changed
  /// files are split over several runs to stay under it. It defaults to what
  /// the platform shell allows. [environment] is the process environment,
  /// which tells when to warn with GitHub Actions annotations.
  ExecCommand({
    required Logger logger,
    required Map<String, String> environment,
    int? maxCommandLength,
  })  : _logger = logger,
        _environment = environment,
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
      ..addOption(
        'base',
        valueHelp: 'commit',
        help: 'Compare with this commit or ref instead of <remote>/<branch>, '
            'e.g. the commit before a push',
      )
      ..addFlag(
        'fetch',
        defaultsTo: true,
        help: 'Run git fetch for the base branch before the diff',
      )
      ..addOption(
        'mode',
        defaultsTo: 'auto',
        allowed: ['auto', ...Mode.values.map((mode) => mode.name)],
        allowedHelp: {
          'auto': 'test for flutter/dart test, package for flutter/dart '
              'analyze, files otherwise',
          'test': 'pass the tests that depend on the changed files',
          'files': 'pass the changed Dart files',
          'package': 'run without files if the package, or a file it '
              'depends on, changed',
        },
        help: 'What to pass to the command',
      )
      ..addFlag(
        'all',
        negatable: false,
        help: 'Run on everything, without looking at the changes',
      )
      ..addMultiOption(
        'run-all-on',
        splitCommas: false,
        valueHelp: 'glob',
        help: 'Run on everything when a changed file matches this glob, '
            'relative to the repository root. Can be repeated.',
      )
      ..addOption(
        'report',
        valueHelp: 'dir',
        help: 'Write a JSON file about this run into this directory '
            '(see the report command)',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Work out what to run without running it; the command is '
            'optional',
      );
  }

  // Stop at the first positional argument, so the wrapped command's options
  // (e.g. `flutter test --coverage`) are not parsed as ours even without
  // `--`. Melos 7 drops the `--` that `melos exec` passes along.
  @override
  final argParser = ArgParser(allowTrailingOptions: false);

  @override
  String get description => 'Execute a command on changed Dart/Flutter files';

  @override
  String get name => 'exec';

  final Logger _logger;
  final Map<String, String> _environment;
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
    final base = args.option('base');
    final target = base ?? '$remote/$branch';

    _logger.detail('Comparing with $target');

    // They are passed to git as arguments, so they must not look like options.
    if ([branch, remote, if (base != null) base]
        .any((v) => v.startsWith('-'))) {
      _logger.err('Error: The branch, remote and base cannot start with "-".');
      return ExitCode.usage.code;
    }

    final command = args.rest;
    final dryRun = args.flag('dry-run');
    if (command.isEmpty && !dryRun) {
      _logger.err('No command specified.\n$usage');
      return 1;
    }
    final modeName = args.option('mode')!;
    final mode = modeName != 'auto'
        ? Mode.values.byName(modeName)
        : command.isEmpty
            ? Mode.package
            : detectMode(command);

    final List<ChangedFile> changed;
    _Plan plan;
    if (args.flag('all')) {
      changed = const [];
      plan = _full('--all was passed');
    } else {
      final files = getModifiedFiles(
        target,
        logger: _logger,
        // The refspec updates <remote>/<branch> in single-branch clones too.
        fetch: !args.flag('fetch')
            ? null
            : [
                remote,
                base ?? '+refs/heads/$branch:refs/remotes/$remote/$branch'
              ],
        warn: _warn,
      );
      if (files == null) return 1;
      changed = files;
      _logger.detail('Changed files[${changed.length}]:');
      for (final file in changed) {
        _logger.detail('  - ${file.path}');
      }
      plan = _plan(
        mode,
        changed,
        args.multiOption('run-all-on').map(globToRegExp).toList(),
      );
    }

    final files =
        plan.ran == 'full' && mode == Mode.files ? listDartFiles() : plan.files;
    var commands = chunkArgs(command, files, _maxCommandLength);
    // Split test or package runs would each overwrite the coverage report
    // and print their own summary, so run everything once instead.
    if (mode == Mode.test && commands.length > 1) {
      plan = _full('too many tests for one command line');
      commands = [command];
    }

    switch (plan.ran) {
      case 'none':
        _logger.info('Nothing to run: ${plan.reason}.');
      case 'full':
        _logger.info('Running on everything: ${plan.reason}.');
      default:
        _logger.info('Running on the ${plan.reason}[${files.length}]:');
        for (final file in files) {
          _logger.info('  - $file');
        }
    }

    final report = args.option('report');
    if (report != null) {
      final prefix = repoPrefix() ?? '';
      String repoPath(String path) => '$prefix$path';
      // A file per run: melos runs several packages at once, and appending
      // to one file from several processes loses lines.
      File(
        '$report/$pid-${DateTime.now().microsecondsSinceEpoch}.json',
      ).writeAsStringSync(
        jsonEncode({
          'package':
              prefix.isEmpty ? '.' : prefix.substring(0, prefix.length - 1),
          'mode': mode.name,
          'ran': plan.ran,
          'reason': plan.reason,
          'base': target,
          'changed': [for (final file in changed) file.repoPath],
          'files': [
            if (plan.ran == 'partial') ...files.map(repoPath),
          ],
        }),
      );
    }

    if (plan.ran == 'none' || dryRun) return 0;

    // Run every chunk, even after a failure, and report the first failure.
    var exitCode = 0;
    for (final command in commands) {
      final code = await runCommand(command, logger: _logger);
      if (exitCode == 0) exitCode = code;
    }
    return exitCode;
  }

  _Plan _plan(Mode mode, List<ChangedFile> changed, List<RegExp> runAllOn) {
    if (changed.isEmpty) return _none('no files changed');
    for (final file in changed) {
      if (runAllOn.any((glob) => glob.hasMatch(file.repoPath)) ||
          (mode != Mode.files && affectsWorkspace(file.path)) ||
          (mode == Mode.test && affectsAllTests(file.path))) {
        return _full('${file.repoPath} changed');
      }
    }

    final local = [
      for (final file in changed)
        if (!file.path.startsWith('../')) file.path,
    ];
    switch (mode) {
      case Mode.files:
        final dart = local
            .where((file) => file.endsWith('.dart') && File(file).existsSync())
            .toList();
        return dart.isEmpty
            ? _none('no changed Dart files')
            : (ran: 'partial', reason: 'changed Dart files', files: dart);
      case Mode.package:
        if (local.isNotEmpty) return _full('${local.first} changed');
        final dependents =
            dependentFiles(changed.map((file) => file.path)).toList()..sort();
        return dependents.isEmpty
            ? _none('nothing in this package or used by it changed')
            : _full('${dependents.first} uses a changed file');
      case Mode.test:
        final tests = {
          ...local,
          ...dependentFiles(changed.map((file) => file.path)),
        }
            .where(
              (file) =>
                  file.endsWith('_test.dart') &&
                  (file.startsWith('test/') || local.contains(file)) &&
                  File(file).existsSync(),
            )
            .toList()
          ..sort();
        if (tests.isEmpty) return _none('no test uses the changed files');
        // `flutter test` alone runs all of them, and reports a full run.
        if (tests.every((file) => file.startsWith('test/')) &&
            tests.length ==
                Directory('test')
                    .listSync(recursive: true)
                    .where((e) => e is File && e.path.endsWith('_test.dart'))
                    .length) {
          return _full('every test uses the changed files');
        }
        return (
          ran: 'partial',
          reason: 'tests that use the changed files',
          files: tests,
        );
    }
  }

  /// Warns, as an annotation on GitHub Actions.
  void _warn(String message) => _environment['GITHUB_ACTIONS'] == 'true'
      ? _logger.info('::warning::$message')
      : _logger.warn(message);
}
