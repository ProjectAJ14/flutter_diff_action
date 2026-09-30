import 'dart:io';

import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/temp_repo.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('calculateTestFile', () {
    test('maps lib/ to test/', () {
      expect(calculateTestFile('lib/src/foo.dart'), 'test/src/foo_test.dart');
    });

    test('only replaces the .dart extension', () {
      expect(
        calculateTestFile('lib/my.dart_utils/a.dart'),
        'test/my.dart_utils/a_test.dart',
      );
    });

    test('keeps files outside lib/ in place', () {
      expect(calculateTestFile('bin/cli.dart'), 'bin/cli_test.dart');
    });
  });

  group('isTestCommand', () {
    test('detects test commands', () {
      expect(isTestCommand(['flutter', 'test']), isTrue);
      expect(isTestCommand(['dart', 'test', '--coverage']), isTrue);
      expect(isTestCommand(['fvm', 'flutter', 'test']), isTrue);
    });

    test('ignores a test/ path argument', () {
      expect(isTestCommand(['dart', 'analyze', 'test']), isFalse);
      expect(isTestCommand(['dart', 'format']), isFalse);
    });
  });

  group('affectsAllTests', () {
    test('is true for config, test helpers and non-Dart assets', () {
      for (final file in [
        'pubspec.yaml',
        'pubspec.lock',
        'dart_test.yaml',
        'build.yaml',
        'l10n.yaml',
        'test/helpers/pump.dart',
        'test/goldens/home.png',
        'lib/l10n/app_en.arb',
        'assets/logo.png',
      ]) {
        expect(affectsAllTests(file), isTrue, reason: file);
      }
    });

    test('is false for source and test files', () {
      for (final file in [
        'lib/a.dart',
        'test/a_test.dart',
        'README.md',
        'example/pubspec.yaml',
      ]) {
        expect(affectsAllTests(file), isFalse, reason: file);
      }
    });
  });

  group('chunkArgs', () {
    test('keeps everything in one command when it fits', () {
      expect(chunkArgs(['dart', 'test'], ['a', 'b'], 100), [
        ['dart', 'test', 'a', 'b'],
      ]);
    });

    test('splits so each command stays within the limit', () {
      // 'cmd a b' is 7 characters.
      expect(chunkArgs(['cmd'], ['a', 'b', 'c', 'd', 'e'], 7), [
        ['cmd', 'a', 'b'],
        ['cmd', 'c', 'd'],
        ['cmd', 'e'],
      ]);
    });

    test('gives a file longer than the limit its own command', () {
      expect(chunkArgs(['cmd'], ['a', 'long_file', 'b'], 7), [
        ['cmd', 'a'],
        ['cmd', 'long_file'],
        ['cmd', 'b'],
      ]);
    });

    test('returns the base command when there are no files', () {
      expect(chunkArgs(['cmd'], [], 7), [
        ['cmd'],
      ]);
    });
  });

  group('getModifiedFiles', () {
    late TempRepo repo;
    late Directory originalCwd;
    late Logger logger;

    setUp(() {
      originalCwd = Directory.current;
      repo = TempRepo();
      logger = _MockLogger();
    });

    tearDown(() {
      Directory.current = originalCwd;
      repo.delete();
    });

    test('finds modified and untracked files at the repo root', () {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('lib/new.dart', 'void n() {}');
      Directory.current = repo.dir;

      expect(
        getModifiedFiles('origin', 'main', logger: logger),
        unorderedEquals(['lib/a.dart', 'lib/new.dart']),
      );
      verify(() => logger.detail('Fetching remote branch: origin/main'))
          .called(1);
      verifyNever(() => logger.warn(any()));
    });

    test('returns paths relative to, and limited to, a sub-package', () {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('packages/pkg/lib/b.dart', 'void b2() {}');
      Directory.current = Directory('${repo.dir.path}/packages/pkg');

      expect(
        getModifiedFiles('origin', 'main', logger: logger),
        ['lib/b.dart'],
      );
    });

    test('ignores changes that landed on the base branch later', () {
      repo
        ..git(['checkout', '-qb', 'feature'])
        ..write('lib/a.dart', 'void a2() {}')
        ..git(['commit', '-qam', 'feature'])
        // Someone else changes b.dart on main.
        ..git(['checkout', '-q', 'main'])
        ..write('packages/pkg/lib/b.dart', 'void b2() {}')
        ..git(['commit', '-qam', 'main'])
        ..git(['push', '-q', 'origin', 'main'])
        ..git(['checkout', '-q', 'feature']);
      Directory.current = repo.dir;

      expect(
        getModifiedFiles('origin', 'main', logger: logger),
        ['lib/a.dart'],
      );
    });

    test('warns and uses the local ref when fetch fails', () {
      repo
        ..git(['remote', 'set-url', 'origin', '${repo.dir.path}/missing'])
        ..write('lib/a.dart', 'void a2() {}');
      Directory.current = repo.dir;

      expect(
        getModifiedFiles('origin', 'main', logger: logger),
        ['lib/a.dart'],
      );
      verify(
        () => logger.warn(
          any(that: startsWith('Could not fetch origin/main')),
        ),
      ).called(1);
    });

    test('skips git fetch when fetch is false', () {
      repo
        ..git(['remote', 'set-url', 'origin', '${repo.dir.path}/missing'])
        ..write('lib/a.dart', 'void a2() {}');
      Directory.current = repo.dir;

      expect(
        getModifiedFiles('origin', 'main', logger: logger, fetch: false),
        ['lib/a.dart'],
      );
      verifyNever(() => logger.detail(any(that: startsWith('Fetching'))));
      verifyNever(() => logger.warn(any()));
    });

    test('falls back to the branch tip when there is no merge base', () {
      repo
        ..git(['checkout', '-q', '--orphan', 'orphan'])
        ..git(['rm', '-rqf', '.'])
        ..write('lib/a.dart', 'void a() {}')
        ..git(['add', '.'])
        ..git(['commit', '-qm', 'orphan'])
        ..git(['push', '-q', 'origin', 'orphan'])
        ..git(['checkout', '-q', 'main']);
      Directory.current = repo.dir;

      expect(
        getModifiedFiles('origin', 'orphan', logger: logger),
        unorderedEquals(['pubspec.yaml', 'packages/pkg/lib/b.dart']),
      );
      verify(
        () => logger.detail(any(that: startsWith('Merge base diff failed'))),
      ).called(1);
    });

    test('returns null when the base branch does not exist', () {
      Directory.current = repo.dir;

      expect(getModifiedFiles('origin', 'missing', logger: logger), isNull);
      verify(
        () => logger.err(
          any(
              that:
                  startsWith('Error running git diff against origin/missing')),
        ),
      ).called(1);
    });

    test('returns null outside a git repository', () {
      final dir = Directory.systemTemp.createTempSync('dart_diff_no_git');
      Directory.current = dir;
      // Windows can't delete the current directory, so leave it first.
      addTearDown(() {
        Directory.current = originalCwd;
        dir.deleteSync(recursive: true);
      });

      expect(getModifiedFiles('origin', 'main', logger: logger), isNull);
      verify(() => logger.err('Error: Not a git repository.')).called(1);
    });
  });
}
