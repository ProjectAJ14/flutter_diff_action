import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_diff_cli/src/commands/commands.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/temp_repo.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('exec', () {
    late TempRepo repo;
    late Directory originalCwd;
    late Logger logger;
    late CommandRunner<int> runner;

    setUp(() {
      originalCwd = Directory.current;
      repo = TempRepo()
        // `git test <files>` lists the files: a test command that exits 0.
        ..git(['config', 'alias.test', 'ls-files']);
      Directory.current = repo.dir;
      logger = _MockLogger();
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(ExecCommand(logger: logger, environment: {}));
    });

    tearDown(() {
      Directory.current = originalCwd;
      repo.delete();
    });

    test('fails without a pubspec.yaml', () async {
      File('pubspec.yaml').deleteSync();

      expect(await runner.run(['exec', '--', 'git', 'test']), 1);
      verify(
        () => logger.err(any(that: startsWith('Error: No pubspec.yaml'))),
      ).called(1);
    });

    test('fails without a command', () async {
      expect(await runner.run(['exec']), 1);
      verify(
        () => logger.err(any(that: startsWith('No command specified.'))),
      ).called(1);
    });

    test('fails when the changed files cannot be determined', () async {
      expect(await runner.run(['exec', '-b', 'missing', '--', 'git']), 1);
      verifyNever(() => logger.info(any(that: startsWith('Running'))));
    });

    test('does nothing when no file changed', () async {
      expect(await runner.run(['exec', '--', 'git', 'ls-files']), 0);
      verify(() => logger.info('Nothing to run: no files changed.')).called(1);
      verifyNever(() => logger.info(any(that: startsWith('Running'))));
    });

    test('does nothing without modified Dart files', () async {
      repo.write('README.md', 'changed');

      expect(await runner.run(['exec', '--', 'git', 'ls-files']), 0);
      verify(() => logger.info('Nothing to run: no changed Dart files.'))
          .called(1);
      verifyNever(() => logger.info(any(that: startsWith('Running:'))));
    });

    test('leaves the command options alone without "--"', () async {
      // melos 7 drops the "--" that melos exec passes to dart_diff.
      repo.write('lib/a.dart', 'void a2() {}');

      expect(
        await runner.run(['exec', '--no-fetch', 'git', 'ls-files', '-m']),
        0,
      );
      verify(() => logger.info('Running: git ls-files -m lib/a.dart'))
          .called(1);
    });

    test('passes existing modified Dart files to other commands', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('lib/new.dart', 'void n() {}')
        ..write('lib/notes.txt', 'not dart')
        ..git(['rm', '-q', 'packages/pkg/lib/b.dart']);

      expect(await runner.run(['exec', '--', 'git', 'ls-files']), 0);
      verify(() => logger.info('Running on the changed Dart files[2]:'))
          .called(1);
      verify(() => logger.info('Running: git ls-files lib/a.dart lib/new.dart'))
          .called(1);
    });

    test('runs the tests that use the changed files', () async {
      repo
        ..write('lib/b.dart', "import 'a.dart';")
        ..write('test/a_test.dart', "import 'package:repo/a.dart';")
        ..write('test/b_test.dart', "import '../lib/b.dart';")
        ..write('test/c_test.dart', 'void main() {}')
        ..write('integration_test/a_test.dart', "import '../lib/a.dart';")
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'tests'])
        ..git(['push', '-q', 'origin', 'main'])
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/d_test.dart', 'void main() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info(
          'Running: git test test/a_test.dart test/b_test.dart '
          'test/d_test.dart',
        ),
      ).called(1);
    });

    test('runs the tests of the files importing a deleted file', () async {
      repo
        ..write('lib/b.dart', "import 'a.dart';")
        ..write('test/b_test.dart', "import 'package:repo/b.dart';")
        ..write('test/c_test.dart', 'void main() {}')
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'test'])
        ..git(['push', '-q', 'origin', 'main'])
        ..git(['rm', '-q', 'lib/a.dart']);

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(() => logger.info('Running: git test test/b_test.dart')).called(1);
    });

    test('runs the full suite when a test fixture changes', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/fixtures/user.json', '{}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info(
          'Running on everything: test/fixtures/user.json changed.',
        ),
      ).called(1);
      verify(() => logger.info('Running: git test')).called(1);
    });

    test('runs nothing when no test uses the changed files', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/c_test.dart', 'void main() {}')
        ..git(['add', 'test'])
        ..git(['commit', '-qm', 'test'])
        ..git(['push', '-q', 'origin', 'main']);

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info('Nothing to run: no test uses the changed files.'),
      ).called(1);
      verifyNever(() => logger.info(any(that: startsWith('Running:'))));
    });

    group('in a sub-package', () {
      setUp(() {
        repo
          ..write('packages/pkg/pubspec.yaml', 'name: pkg')
          ..write('packages/pkg/test/b_test.dart', "import '../lib/b.dart';")
          ..write('packages/pkg/lib/c.dart', "import '../../../lib/a.dart';")
          ..write('packages/pkg/test/c_test.dart', "import '../lib/c.dart';")
          ..git(['add', '.'])
          ..git(['commit', '-qm', 'pkg'])
          ..git(['push', '-q', 'origin', 'main']);
        Directory.current = Directory('${repo.dir.path}/packages/pkg');
      });

      test('runs the tests that use a changed file outside it', () async {
        repo.write('lib/a.dart', 'void a2() {}');

        expect(await runner.run(['exec', '--', 'git', 'test']), 0);
        verify(() => logger.info('Running: git test test/c_test.dart'))
            .called(1);
      });

      test('runs the full suite when the workspace lock file changes',
          () async {
        repo.write('pubspec.lock', 'packages: {}');

        expect(await runner.run(['exec', '--', 'git', 'test']), 0);
        verify(() =>
                logger.info('Running on everything: pubspec.lock changed.'))
            .called(1);
      });

      test('in package mode, runs when the package changed', () async {
        repo.write('packages/pkg/README.md', 'changed');

        expect(
          await runner.run(['exec', '--mode', 'package', 'git', 'ls-files']),
          0,
        );
        verify(() => logger.info('Running on everything: README.md changed.'))
            .called(1);
        verify(() => logger.info('Running: git ls-files')).called(1);
      });

      test('in package mode, runs when a file it uses changed', () async {
        repo.write('lib/a.dart', 'void a2() {}');

        expect(
          await runner.run(['exec', '--mode', 'package', 'git', 'ls-files']),
          0,
        );
        verify(
          () => logger.info(
            'Running on everything: lib/c.dart uses a changed file.',
          ),
        ).called(1);
      });

      test('in package mode, does nothing when nothing it uses changed',
          () async {
        repo.write('README.md', 'changed');

        expect(
          await runner.run(['exec', '--mode', 'package', 'git', 'ls-files']),
          0,
        );
        verify(
          () => logger.info(
            'Nothing to run: nothing in this package or used by it changed.',
          ),
        ).called(1);
      });

      test('reports each run to a file of its own', () async {
        final report = Directory('${repo.dir.parent.path}/report')
          ..createSync();
        repo.write('lib/a.dart', 'void a2() {}');

        for (var i = 0; i < 2; i++) {
          expect(
            await runner.run(
              ['exec', '--report', report.path, '--dry-run', 'git', 'test'],
            ),
            0,
          );
        }
        verifyNever(() => logger.info(any(that: startsWith('Running:'))));
        final files = report.listSync().cast<File>();
        expect(files, hasLength(2));
        expect(jsonDecode(files.first.readAsStringSync()), {
          'package': 'packages/pkg',
          'mode': 'test',
          'ran': 'partial',
          'reason': 'tests that use the changed files',
          'base': 'origin/main',
          'changed': ['lib/a.dart'],
          'files': ['packages/pkg/test/c_test.dart'],
        });
      });
    });

    test('works out what would run without a command on a dry run', () async {
      final report = Directory('${repo.dir.parent.path}/report')..createSync();
      repo.write('lib/a.dart', 'void a2() {}');

      expect(
        await runner.run(['exec', '--dry-run', '--report', report.path]),
        0,
      );
      final file = report.listSync().single as File;
      expect(jsonDecode(file.readAsStringSync()), {
        'package': '.',
        'mode': 'package',
        'ran': 'full',
        'reason': 'lib/a.dart changed',
        'base': 'origin/main',
        'changed': ['lib/a.dart'],
        'files': <String>[],
      });
    });

    test('runs everything with --all', () async {
      repo.write('lib/new.dart', 'void n() {}');

      expect(await runner.run(['exec', '--all', '--', 'git', 'test']), 0);
      verify(() => logger.info('Running on everything: --all was passed.'))
          .called(1);
      verify(() => logger.info('Running: git test')).called(1);

      // Other commands get every Dart file.
      expect(await runner.run(['exec', '--all', '--', 'git', 'ls-files']), 0);
      verify(
        () => logger.info(
          'Running: git ls-files lib/a.dart lib/new.dart '
          'packages/pkg/lib/b.dart',
        ),
      ).called(1);
    });

    test('runs everything when a file matches --run-all-on', () async {
      repo.write('tools/gen/config.yaml', 'x: 1');

      expect(
        await runner.run(
          ['exec', '--run-all-on', 'tools/**', '--', 'git', 'test'],
        ),
        0,
      );
      verify(
        () => logger.info(
          'Running on everything: tools/gen/config.yaml changed.',
        ),
      ).called(1);
    });

    test('compares with --base', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..git(['commit', '-qam', 'second']);

      expect(
        await runner.run(['exec', '--base', 'HEAD~1', '--', 'git', 'ls-files']),
        0,
      );
      verify(() => logger.info('Running: git ls-files lib/a.dart')).called(1);
    });

    test('rejects a branch, remote or base that looks like an option',
        () async {
      for (final args in [
        ['-b', '--upload-pack=x'],
        ['-r', '-x'],
        ['--base', '-x'],
      ]) {
        expect(
          await runner.run(['exec', ...args, '--', 'git', 'ls-files']),
          ExitCode.usage.code,
        );
      }
      verify(
        () => logger.err(
          'Error: The branch, remote and base cannot start with "-".',
        ),
      ).called(3);
    });

    test('runs the full suite when every test is selected', () async {
      final report = Directory('${repo.dir.parent.path}/report')..createSync();
      repo
        ..write('test/a_test.dart', 'void main() {}')
        ..write('test/nested/b_test.dart', 'void main() {}')
        // Not a test: `flutter test` only runs *_test.dart files.
        ..write('test/helpers.dart', 'void help() {}');

      expect(
        await runner.run(
          ['exec', '--report', report.path, '--', 'git', 'test'],
        ),
        0,
      );
      verify(
        () => logger.info(
          'Running on everything: every test uses the changed files.',
        ),
      ).called(1);
      verify(() => logger.info('Running: git test')).called(1);
      final file = report.listSync().single as File;
      expect(jsonDecode(file.readAsStringSync()), containsPair('ran', 'full'));
    });

    test('runs only the selected tests when a test outside test/ is picked',
        () async {
      // As many picked tests as files under test/, but not the same ones.
      repo
        ..write('test/b_test.dart', 'void main() {}')
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'test'])
        ..git(['push', '-q', 'origin', 'main'])
        ..write('test/a_test.dart', 'void main() {}')
        // `flutter test` alone wouldn't run it.
        ..write('lib/a_test.dart', 'void main() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info('Running: git test lib/a_test.dart test/a_test.dart'),
      ).called(1);
    });

    test('runs the full suite instead of splitting a test run', () async {
      repo
        ..write('test/c_test.dart', 'void main() {}')
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'test'])
        ..git(['push', '-q', 'origin', 'main'])
        ..write('test/a_test.dart', 'void main() {}')
        ..write('test/b_test.dart', 'void main() {}');
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(
          ExecCommand(logger: logger, maxCommandLength: 1, environment: {}),
        );

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info(
          'Running on everything: too many tests for one command line.',
        ),
      ).called(1);
      verify(() => logger.info('Running: git test')).called(1);
    });

    test('runs every chunk and returns the first failing exit code', () async {
      // Outside the repo, so it is not a changed file itself.
      final script = File('${repo.dir.parent.path}/exit.dart')
        ..writeAsStringSync('''
import 'dart:io';

void main(List<String> args) => exit(
      args.contains('lib/fail.dart')
          ? 3
          : args.contains('lib/z.dart')
              ? 4
              : 0,
    );
''');
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('lib/fail.dart', 'void f() {}')
        ..write('lib/z.dart', 'void z() {}');
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(
          ExecCommand(logger: logger, maxCommandLength: 1, environment: {}),
        );

      final exitCode = await runner.run(
        ['exec', '--', Platform.resolvedExecutable, script.path],
      );

      expect(exitCode, 3);
      final base = 'Running: ${Platform.resolvedExecutable} ${script.path}';
      for (final file in ['lib/a.dart', 'lib/fail.dart', 'lib/z.dart']) {
        verify(() => logger.info('$base $file')).called(1);
      }
    });

    test('skips git fetch with --no-fetch', () async {
      repo
        ..git(['remote', 'set-url', 'origin', '${repo.dir.path}/missing'])
        ..write('lib/a.dart', 'void a2() {}');

      expect(
        await runner.run(['exec', '--no-fetch', '--', 'git', 'ls-files']),
        0,
      );
      verifyNever(
        () => logger.warn(any(that: startsWith('Could not fetch'))),
      );
      verify(() => logger.info('Running: git ls-files lib/a.dart')).called(1);
    });

    test('warns with an annotation on GitHub Actions', () async {
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(
          ExecCommand(logger: logger, environment: {'GITHUB_ACTIONS': 'true'}),
        );

      expect(await runner.run(['exec', '--', 'git', 'ls-files']), 0);
      verify(
        () => logger.info(
          '::warning::HEAD is already part of origin/main, '
          'so only uncommitted changes count.',
        ),
      ).called(1);
    });
  });
}
