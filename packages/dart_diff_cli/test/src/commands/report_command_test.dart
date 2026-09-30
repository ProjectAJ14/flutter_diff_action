import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/commands/commands.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('report', () {
    late Directory dir;
    late CommandRunner<int> runner;
    late String report, output, summary;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dart_diff_report');
      report = '${dir.path}/report';
      output = '${dir.path}/output';
      summary = '${dir.path}/summary.md';
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(ReportCommand(logger: _MockLogger()));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    void record(String package, String mode, String ran, List<String> files) =>
        (File('$report/$package.json')..createSync(recursive: true))
            .writeAsStringSync(
          jsonEncode({
            'package': package,
            'mode': mode,
            'ran': ran,
            'reason': 'why',
            'base': 'origin/main',
            'changed': ['core/lib/a.dart', 'README.md'],
            'files': files,
          }),
        );

    Future<Map<String, String>> run() async {
      expect(
        await runner.run(
          ['report', '--output', output, '--summary', summary, report],
        ),
        0,
      );
      return {
        for (final line in File(output).readAsLinesSync())
          line.substring(0, line.indexOf('=')):
              line.substring(line.indexOf('=') + 1),
      };
    }

    test('sums up the runs of several packages', () async {
      record('core', 'test', 'partial', ['core/test/a_test.dart']);
      record('app', 'test', 'full', []);
      record('api', 'test', 'none', []);

      expect(await run(), {
        'ran': 'partial',
        'full-suite': 'false',
        'skipped': 'false',
        'changed-files': '["README.md","core/lib/a.dart"]',
        'files': '["core/test/a_test.dart"]',
        'test-files': '["core/test/a_test.dart"]',
        'packages': '["app","core"]',
      });
      final markdown = File(summary).readAsStringSync();
      expect(markdown, contains('| `core` | test | partial | why |'));
      expect(markdown, contains('Files passed to the command (1)'));
      expect(markdown, contains('- `README.md`'));
    });

    test('is full when every run was full', () async {
      record('.', 'package', 'full', []);

      final outputs = await run();
      expect(outputs['ran'], 'full');
      expect(outputs['full-suite'], 'true');
      expect(outputs['test-files'], '[]');
      expect(
        File(summary).readAsStringSync(),
        isNot(contains('Files passed')),
      );
    });

    test('is none when nothing ran or the report is missing', () async {
      final outputs = await run();
      expect(outputs['ran'], 'none');
      expect(outputs['skipped'], 'true');
      expect(outputs['packages'], '[]');
      expect(File(summary).readAsStringSync(), contains('Nothing ran'));
    });

    test('needs exactly one report file', () async {
      expect(() => runner.run(['report']), throwsA(isA<UsageException>()));
    });

    test('writes nothing without --output and --summary', () async {
      record('.', 'files', 'partial', ['lib/a.dart']);

      expect(await runner.run(['report', report]), 0);
      expect(File(output).existsSync(), isFalse);
      expect(File(summary).existsSync(), isFalse);
    });
  });
}
