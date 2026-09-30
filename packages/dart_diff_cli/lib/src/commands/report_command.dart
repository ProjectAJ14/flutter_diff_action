import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// Sums up the runs that `exec --report <dir>` recorded, e.g. one per
/// package of a mono-repo, as GitHub Actions outputs and a Markdown summary.
class ReportCommand extends Command<int> {
  /// Creates a new instance of [ReportCommand].
  ReportCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'output',
        valueHelp: 'file',
        help: r'Append the outputs to this file, e.g. $GITHUB_OUTPUT',
      )
      ..addOption(
        'summary',
        valueHelp: 'file',
        help: r'Append a Markdown summary to this file, '
            r'e.g. $GITHUB_STEP_SUMMARY',
      );
  }

  @override
  String get description => 'Sum up the runs recorded by exec --report <dir>';

  @override
  String get name => 'report';

  @override
  String get invocation => 'dart_diff report [options] <dir>';

  final Logger _logger;

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Pass one report directory.');
    final dir = Directory(args.rest.single);
    final runs = [
      if (dir.existsSync())
        for (final file in dir.listSync().whereType<File>())
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    ]..sort((a, b) => '${a['package']}'.compareTo('${b['package']}'));

    List<String> all(String key, [bool Function(Map<String, Object?>)? test]) {
      final values = {
        for (final run in runs)
          if (test == null || test(run)) ...(run[key]! as List).cast<String>(),
      }.toList();
      return values..sort();
    }

    final ran = runs.every((run) => run['ran'] == 'none')
        ? 'none'
        : runs.every((run) => run['ran'] == 'full')
            ? 'full'
            : 'partial';
    final outputs = {
      'ran': ran,
      'full-suite': '${ran == 'full'}',
      'skipped': '${ran == 'none'}',
      'changed-files': jsonEncode(all('changed')),
      'files': jsonEncode(all('files')),
      'test-files': jsonEncode(all('files', (run) => run['mode'] == 'test')),
      'packages': jsonEncode([
        for (final run in runs)
          if (run['ran'] != 'none') run['package'],
      ]),
    };
    for (final MapEntry(:key, :value) in outputs.entries) {
      _logger.detail('$key=$value');
    }

    final output = args.option('output');
    if (output != null) {
      File(output).writeAsStringSync(
        outputs.entries.map((e) => '${e.key}=${e.value}\n').join(),
        mode: FileMode.append,
      );
    }
    final summary = args.option('summary');
    if (summary != null) {
      File(summary)
          .writeAsStringSync(_markdown(runs, ran), mode: FileMode.append);
    }
    return ExitCode.success.code;
  }

  String _markdown(List<Map<String, Object?>> runs, String ran) {
    final out = StringBuffer('### dart_diff\n\n');
    if (runs.isEmpty) {
      return '${out}Nothing ran: no package had changes.\n';
    }
    out
      ..writeln('Compared with `${runs.first['base']}`. Ran: **$ran**.')
      ..writeln()
      ..writeln('| Package | Mode | Ran | Why |')
      ..writeln('|---|---|---|---|');
    for (final run in runs) {
      out.writeln('| `${run['package']}` | ${run['mode']} | ${run['ran']} '
          '| ${run['reason']} |');
    }
    void list(String title, Iterable<Object?> files) {
      if (files.isEmpty) return;
      out
        ..writeln()
        ..writeln('<details><summary>$title (${files.length})</summary>')
        ..writeln();
      for (final file in files) {
        out.writeln('- `$file`');
      }
      out.writeln('</details>');
    }

    list('Files passed to the command', {
      for (final run in runs) ...run['files']! as List,
    });
    list('Changed files', {for (final run in runs) ...run['changed']! as List});
    return out.toString();
  }
}
