import 'dart:io';

import 'package:dart_diff_cli/src/utils/index.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/temp_repo.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('detectMode', () {
    test('detects test commands', () {
      expect(detectMode(['flutter', 'test']), Mode.test);
      expect(detectMode(['dart', 'test', '--coverage']), Mode.test);
      expect(detectMode(['fvm', 'flutter', 'test']), Mode.test);
    });

    test('runs analyze on the whole package', () {
      expect(detectMode(['flutter', 'analyze']), Mode.package);
      expect(detectMode(['fvm', 'dart', 'analyze', 'lib']), Mode.package);
    });

    test('passes files to other commands', () {
      expect(detectMode(['dart', 'format']), Mode.files);
      expect(detectMode(['dart', 'fix', 'test']), Mode.files);
    });
  });

  group('affectsAllTests', () {
    test('is true for config, test fixtures and non-Dart assets', () {
      for (final file in [
        'pubspec.yaml',
        'pubspec.lock',
        'pubspec_overrides.yaml',
        'dart_test.yaml',
        'build.yaml',
        'l10n.yaml',
        'test/flutter_test_config.dart',
        'test/goldens/home.png',
        'lib/l10n/app_en.arb',
        'assets/logo.png',
      ]) {
        expect(affectsAllTests(file), isTrue, reason: file);
      }
    });

    test('is false for Dart files, which imports are followed for', () {
      for (final file in [
        'lib/a.dart',
        'test/a_test.dart',
        'test/helpers/pump.dart',
        'README.md',
        'example/pubspec.yaml',
      ]) {
        expect(affectsAllTests(file), isFalse, reason: file);
      }
    });
  });

  group('affectsWorkspace', () {
    test('is true for workspace config in a parent directory', () {
      for (final file in [
        '../pubspec.lock',
        '../../pubspec.yaml',
        '../../melos.yaml',
        '../../analysis_options.yaml',
        '../pubspec_overrides.yaml',
      ]) {
        expect(affectsWorkspace(file), isTrue, reason: file);
      }
    });

    test('is false elsewhere', () {
      for (final file in [
        'pubspec.lock',
        '../README.md',
        '../other/pubspec.yaml',
      ]) {
        expect(affectsWorkspace(file), isFalse, reason: file);
      }
    });
  });

  group('globToRegExp', () {
    bool matches(String glob, String path) => globToRegExp(glob).hasMatch(path);

    test('keeps * and ? within a directory', () {
      expect(matches('tools/*.dart', 'tools/a.dart'), isTrue);
      expect(matches('tools/*.dart', 'tools/sub/a.dart'), isFalse);
      expect(matches('?.env', 'a.env'), isTrue);
      expect(matches('?.env', 'ab.env'), isFalse);
    });

    test('crosses directories with **', () {
      expect(matches('.github/**', '.github/workflows/ci.yaml'), isTrue);
      expect(matches('**/*.yaml', 'melos.yaml'), isTrue);
      expect(matches('**/*.yaml', 'a/b/c.yaml'), isTrue);
      expect(matches('**/*.yaml', 'a/b/c.yml'), isFalse);
    });

    test('matches whole paths and escapes other characters', () {
      expect(matches('a+b.txt', 'a+b.txt'), isTrue);
      expect(matches('a.txt', 'xa.txt'), isFalse);
      expect(matches('a.txt', 'a_txt'), isFalse);
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

    List<String>? paths(List<ChangedFile>? files) =>
        files?.map((file) => file.path).toList();

    test('finds modified and untracked files at the repo root', () {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('lib/new.dart', 'void n() {}');
      Directory.current = repo.dir;

      expect(
        paths(
          getModifiedFiles(
            'origin/main',
            logger: logger,
            fetch: ['origin', 'main'],
          ),
        ),
        unorderedEquals(['lib/a.dart', 'lib/new.dart']),
      );
      verify(() => logger.detail('Fetching: git fetch origin main')).called(1);
      verifyNever(() => logger.warn(any(that: startsWith('Could not fetch'))));
    });

    test('warns when HEAD is already part of the base', () {
      Directory.current = repo.dir;

      expect(getModifiedFiles('origin/main', logger: logger), isEmpty);
      verify(
        () => logger.warn(
          'HEAD is already part of origin/main, '
          'so only uncommitted changes count.',
        ),
      ).called(1);
    });

    test('reports files outside a sub-package relative to it', () {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..write('packages/pkg/lib/b.dart', 'void b2() {}')
        ..write('packages/pkg/lib/new.dart', 'void n() {}')
        ..write('root.txt', 'untracked');
      Directory.current = Directory('${repo.dir.path}/packages/pkg');

      final files = getModifiedFiles('origin/main', logger: logger);
      expect(
        files,
        unorderedEquals([
          (path: '../../lib/a.dart', repoPath: 'lib/a.dart'),
          (path: 'lib/b.dart', repoPath: 'packages/pkg/lib/b.dart'),
          (path: 'lib/new.dart', repoPath: 'packages/pkg/lib/new.dart'),
          (path: '../../root.txt', repoPath: 'root.txt'),
        ]),
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
        paths(
          getModifiedFiles(
            'origin/main',
            logger: logger,
            fetch: ['origin', 'main'],
          ),
        ),
        ['lib/a.dart'],
      );
      verifyNever(() => logger.warn(any()));
    });

    test('compares with any commit', () {
      repo
        ..write('lib/a.dart', 'void a2() {}')
        ..git(['commit', '-qam', 'second'])
        ..write('lib/c.dart', 'void c() {}');
      Directory.current = repo.dir;

      expect(
        paths(getModifiedFiles('HEAD~1', logger: logger)),
        unorderedEquals(['lib/a.dart', 'lib/c.dart']),
      );
    });

    test('warns and uses the local ref when fetch fails', () {
      repo
        ..git(['remote', 'set-url', 'origin', '${repo.dir.path}/missing'])
        ..write('lib/a.dart', 'void a2() {}');
      Directory.current = repo.dir;
      final warnings = <String>[];

      expect(
        paths(
          getModifiedFiles(
            'origin/main',
            logger: logger,
            fetch: ['origin', 'main'],
            warn: warnings.add,
          ),
        ),
        ['lib/a.dart'],
      );
      expect(warnings.first, startsWith('Could not fetch origin/main'));
    });

    test('skips git fetch without fetch arguments', () {
      repo
        ..git(['remote', 'set-url', 'origin', '${repo.dir.path}/missing'])
        ..write('lib/a.dart', 'void a2() {}');
      Directory.current = repo.dir;

      expect(
        paths(getModifiedFiles('origin/main', logger: logger)),
        ['lib/a.dart'],
      );
      verifyNever(() => logger.detail(any(that: startsWith('Fetching'))));
    });

    test('fetches more history when a shallow clone lacks the merge base', () {
      repo
        ..git(['checkout', '-qb', 'feature'])
        ..write('lib/a.dart', 'void a2() {}')
        ..git(['commit', '-qam', 'feature'])
        ..git(['push', '-q', 'origin', 'feature'])
        ..git(['checkout', '-q', 'main']);
      for (var i = 0; i < 3; i++) {
        repo
          ..write('packages/pkg/lib/b.dart', 'void b$i() {}')
          ..git(['commit', '-qam', 'main $i']);
      }
      repo.git(['push', '-q', 'origin', 'main']);
      final clone = '${repo.dir.parent.path}/clone';
      const main = '+refs/heads/main:refs/remotes/origin/main';
      final origin = Uri.directory('${repo.dir.parent.path}/origin');
      for (final args in [
        ['clone', '-q', '--depth', '1', '-b', 'feature', '$origin', clone],
        ['-C', clone, 'fetch', '-q', '--depth', '1', 'origin', main],
      ]) {
        expect(Process.runSync('git', args).exitCode, 0, reason: '$args');
      }
      Directory.current = Directory(clone);

      expect(
        paths(
          getModifiedFiles(
            'origin/main',
            logger: logger,
            fetch: ['origin', main],
          ),
        ),
        ['lib/a.dart'],
      );
      verify(
        () => logger.detail(
          'No merge base with origin/main, deepening the history by 100',
        ),
      ).called(1);
      verifyNever(() => logger.warn(any()));
    });

    test('deepens a shallow pull request merge commit by 1', () {
      // Like actions/checkout on a pull request: HEAD is the merge commit,
      // whose first parent is the base.
      repo
        ..git(['checkout', '-qb', 'feature'])
        ..write('lib/a.dart', 'void a2() {}')
        ..git(['commit', '-qam', 'feature'])
        ..git(['checkout', '-q', 'main'])
        ..write('packages/pkg/lib/b.dart', 'void b2() {}')
        ..git(['commit', '-qam', 'main'])
        ..git(['push', '-q', 'origin', 'main'])
        ..git(['checkout', '-qb', 'merge'])
        ..git(['merge', '-q', '--no-ff', '-m', 'merge', 'feature'])
        ..git(['push', '-q', 'origin', 'merge']);
      final clone = '${repo.dir.parent.path}/clone';
      const main = '+refs/heads/main:refs/remotes/origin/main';
      final origin = Uri.directory('${repo.dir.parent.path}/origin');
      expect(
        Process.runSync(
          'git',
          ['clone', '-q', '--depth', '1', '-b', 'merge', '$origin', clone],
        ).exitCode,
        0,
      );
      Directory.current = Directory(clone);

      expect(
        paths(
          getModifiedFiles(
            'origin/main',
            logger: logger,
            fetch: ['origin', main],
          ),
        ),
        ['lib/a.dart'],
      );
      verify(
        () => logger.detail(
          'No merge base with origin/main, deepening the history by 1',
        ),
      ).called(1);
      verifyNever(
        () => logger.detail(
          'No merge base with origin/main, deepening the history by 100',
        ),
      );
      verifyNever(() => logger.warn(any()));
    });

    test('warns and diffs against the base when there is no merge base', () {
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
        paths(getModifiedFiles('origin/orphan', logger: logger)),
        unorderedEquals(['pubspec.yaml', 'packages/pkg/lib/b.dart']),
      );
      verify(
        () => logger.warn(any(that: startsWith('No merge base with origin'))),
      ).called(1);
    });

    test('returns null when the base does not exist', () {
      Directory.current = repo.dir;

      expect(getModifiedFiles('origin/missing', logger: logger), isNull);
      verify(
        () => logger.err('Error: origin/missing is not a known commit.'),
      ).called(1);
    });

    test('returns null when git diff fails', () {
      Directory.current = repo.dir;
      // An unreadable index makes git diff, but not rev-parse, fail.
      File('${repo.dir.path}/.git/index').writeAsStringSync('broken');

      expect(getModifiedFiles('origin/main', logger: logger), isNull);
      verify(
        () => logger.err(any(that: startsWith('Error running git diff'))),
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

      expect(getModifiedFiles('origin/main', logger: logger), isNull);
      verify(() => logger.err('Error: Not a git repository.')).called(1);
      expect(repoPrefix(), isNull);
    });

    test('repoPrefix gives the directory within the repository', () {
      Directory.current = repo.dir;
      expect(repoPrefix(), '');
      Directory.current = Directory('${repo.dir.path}/packages/pkg');
      expect(repoPrefix(), 'packages/pkg/');
    });

    test('listDartFiles lists existing Dart files under the directory', () {
      repo
        ..write('packages/pkg/lib/new.dart', 'void n() {}')
        ..write('packages/pkg/README.md', 'not dart');
      File('${repo.dir.path}/packages/pkg/lib/b.dart').deleteSync();
      Directory.current = Directory('${repo.dir.path}/packages/pkg');

      expect(listDartFiles(), ['lib/new.dart']);
    });
  });

  group('dependentFiles', () {
    late Directory originalCwd;
    late Directory root;

    void write(String path, String content) =>
        (File('${root.path}/$path')..createSync(recursive: true))
            .writeAsStringSync(content);

    setUp(() {
      originalCwd = Directory.current;
      root = Directory.systemTemp.createTempSync('dart_diff_graph');
    });

    tearDown(() {
      Directory.current = originalCwd;
      root.deleteSync(recursive: true);
    });

    test('follows imports, exports and parts within the package', () {
      write('pubspec.yaml', 'name: app\n');
      write('lib/a.dart', "export 'src/b.dart';\npart 'a.g.dart';\n");
      write('lib/a.g.dart', "part of 'a.dart';\n");
      write('lib/src/b.dart', "import '../c.dart' as c show x;\n");
      write('lib/c.dart', 'void x() {}');
      write('lib/other.dart', "import 'dart:io';\n");
      write(
        'test/a_test.dart',
        "import 'package:app/a.dart';\nimport 'package:args/args.dart';\n",
      );
      write(
        'test/cond_test.dart',
        'import "stub.dart"\n    if (dart.library.io) "package:app/c.dart";\n',
      );
      write('test/bad_test.dart', "import 'http://[';\n");
      write('test/other_test.dart', "import 'package:app/other.dart';\n");
      Directory.current = root;

      expect(
        dependentFiles(['lib/c.dart']),
        {
          'lib/src/b.dart',
          'lib/a.dart',
          'test/a_test.dart',
          'test/cond_test.dart'
        },
      );
      expect(
          dependentFiles(['lib/a.g.dart']), {'lib/a.dart', 'test/a_test.dart'});
      expect(dependentFiles(['lib/a.dart']), {'test/a_test.dart'});
    });

    test('finds the files importing a deleted file', () {
      write('pubspec.yaml', 'name: app\n');
      write('lib/a.dart', "import 'gone.dart';\n");
      Directory.current = root;

      expect(dependentFiles(['lib/gone.dart']), {'lib/a.dart'});
    });

    test('follows only package: imports of this package without a config', () {
      write('pubspec.yaml', 'description: no name\n');
      write('lib/a.dart', 'void a() {}');
      write('test/a_test.dart', "import 'package:app/a.dart';\n");
      Directory.current = root;

      expect(dependentFiles(['lib/a.dart']), isEmpty);
    });

    test('follows imports into other local packages', () {
      write('pubspec.yaml', 'name: workspace\n');
      write('.dart_tool/package_config.json', '''
{
  "configVersion": 2,
  "packages": [
    {"name": "app", "rootUri": "../app", "packageUri": "lib/"},
    {"name": "core", "rootUri": "../core/", "packageUri": "lib/"},
    {"name": "args", "rootUri": "file:///pub-cache/args", "packageUri": "lib/"}
  ]
}
''');
      write('app/pubspec.yaml', 'name: app\n');
      write('app/lib/app.dart', "import 'package:core/core.dart';\n");
      write('app/test/app_test.dart', "import 'package:app/app.dart';\n");
      write('app/test/args_test.dart', "import 'package:args/args.dart';\n");
      write('core/lib/core.dart', "import 'src/util.dart';\n");
      write('core/lib/src/util.dart', 'void util() {}');
      Directory.current = Directory('${root.path}/app');

      expect(
        dependentFiles(['../core/lib/src/util.dart']),
        {'lib/app.dart', 'test/app_test.dart'},
      );
    });
  });
}
