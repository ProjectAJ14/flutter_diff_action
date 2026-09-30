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
        ..addCommand(ExecCommand(logger: logger));
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

    test('does nothing without modified Dart files', () async {
      repo.write('README.md', 'changed');

      expect(await runner.run(['exec', '--', 'git', 'ls-files']), 0);
      verify(() => logger.info('No modified Dart files detected.')).called(1);
      verifyNever(() => logger.info(any(that: startsWith('Running'))));
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
      verify(() => logger.info('Modified Dart files[2]:')).called(1);
      verify(() => logger.info('Running: git ls-files lib/a.dart lib/new.dart'))
          .called(1);
    });

    test('maps changed files to their tests for test commands', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/a_test.dart', 'void main() {}')
        ..write('test/b_test.dart', 'void main() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () =>
            logger.info('Running: git test test/a_test.dart test/b_test.dart'),
      ).called(1);
    });

    test('runs the full suite when a test helper changes', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/helpers.dart', 'void pump() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info(
          'test/helpers.dart changed, running the full test suite.',
        ),
      ).called(1);
      verify(() => logger.info('Running: git test')).called(1);
    });

    test('runs the full suite when a source file is deleted', () async {
      repo
        ..write('test/a_test.dart', 'void main() {}')
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'test'])
        ..git(['push', '-q', 'origin', 'main'])
        ..git(['rm', '-q', 'lib/a.dart']);

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info('lib/a.dart changed, running the full test suite.'),
      ).called(1);
      verify(() => logger.info('Running: git test')).called(1);
    });

    test('skips changed files that have no test', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('bin/tool.dart', 'void main() {}')
        ..write('test/a_test.dart', 'void main() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(() => logger.info('Running: git test test/a_test.dart')).called(1);
    });

    test('runs nothing when no changed file has a test', () async {
      repo.write('bin/tool.dart', 'void main() {}');

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(() => logger.info('No files to process.')).called(1);
      verifyNever(() => logger.info(any(that: startsWith('Running:'))));
    });

    test('rejects a branch or remote that looks like an option', () async {
      for (final args in [
        ['-b', '--upload-pack=x'],
        ['-r', '-x'],
      ]) {
        expect(
          await runner.run(['exec', ...args, '--', 'git', 'ls-files']),
          ExitCode.usage.code,
        );
      }
      verify(
        () => logger.err('Error: The branch and remote cannot start with "-".'),
      ).called(2);
    });

    test('runs the full suite instead of splitting a test run', () async {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('test/a_test.dart', 'void main() {}')
        ..write('test/b_test.dart', 'void main() {}');
      runner = CommandRunner<int>('dart_diff', '')
        ..addCommand(ExecCommand(logger: logger, maxCommandLength: 1));

      expect(await runner.run(['exec', '--', 'git', 'test']), 0);
      verify(
        () => logger.info(
          'Too many test files for one command line, '
          'running the full test suite.',
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
        ..addCommand(ExecCommand(logger: logger, maxCommandLength: 1));

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
      verifyNever(() => logger.warn(any()));
      verify(() => logger.info('Running: git ls-files lib/a.dart')).called(1);
    });
  });
}
