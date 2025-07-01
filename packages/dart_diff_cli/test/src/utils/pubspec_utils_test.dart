import 'dart:io';

import 'package:dart_diff_cli/src/utils/pubspec_utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

void main() {
  group('PubspecUtils', () {
    late Logger logger;

    setUp(() {
      logger = Logger(level: Level.quiet);
    });

    group('getChangedPubspecFiles', () {
      test('filters pubspec.yaml files correctly', () {
        final modifiedFiles = [
          'lib/main.dart',
          'pubspec.yaml',
          'packages/core/pubspec.yaml',
          'test/main_test.dart',
          'README.md',
        ];

        final result = PubspecUtils.getChangedPubspecFiles(
          modifiedFiles,
          logger: logger,
        );

        expect(result, equals(['pubspec.yaml', 'packages/core/pubspec.yaml']));
      });

      test('returns empty list when no pubspec files changed', () {
        final modifiedFiles = [
          'lib/main.dart',
          'test/main_test.dart',
          'README.md',
        ];

        final result = PubspecUtils.getChangedPubspecFiles(
          modifiedFiles,
          logger: logger,
        );

        expect(result, isEmpty);
      });
    });

    group('compareDependencies', () {
      test('detects added dependencies', () {
        final currentPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final previousPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
''');

        final changes = PubspecUtils.compareDependencies(
          currentPubspec,
          previousPubspec,
          logger: logger,
        );

        expect(changes.hasChanges, isTrue);
        expect(changes.added, hasLength(1));
        expect(changes.added.first.name, equals('http'));
        expect(changes.removed, isEmpty);
        expect(changes.modified, isEmpty);
      });

      test('detects removed dependencies', () {
        final currentPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
''');

        final previousPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final changes = PubspecUtils.compareDependencies(
          currentPubspec,
          previousPubspec,
          logger: logger,
        );

        expect(changes.hasChanges, isTrue);
        expect(changes.added, isEmpty);
        expect(changes.removed, hasLength(1));
        expect(changes.removed.first.name, equals('http'));
        expect(changes.modified, isEmpty);
      });

      test('detects modified dependencies', () {
        final currentPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
''');

        final previousPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final changes = PubspecUtils.compareDependencies(
          currentPubspec,
          previousPubspec,
          logger: logger,
        );

        expect(changes.hasChanges, isTrue);
        expect(changes.added, isEmpty);
        expect(changes.removed, isEmpty);
        expect(changes.modified, hasLength(1));
        expect(changes.modified.first.name, equals('http'));
      });

      test('detects dev dependency changes', () {
        final currentPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  test: ^1.0.0
  mockito: ^5.0.0
''');

        final previousPubspec = Pubspec.parse('''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  test: ^1.0.0
''');

        final changes = PubspecUtils.compareDependencies(
          currentPubspec,
          previousPubspec,
          logger: logger,
        );

        expect(changes.hasChanges, isTrue);
        expect(changes.added, hasLength(1));
        expect(changes.added.first.name, equals('mockito'));
        expect(changes.added.first.isDev, isTrue);
      });

      test('returns no changes when dependencies are identical', () {
        final pubspecContent = '''
name: test_package
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''';

        final currentPubspec = Pubspec.parse(pubspecContent);
        final previousPubspec = Pubspec.parse(pubspecContent);

        final changes = PubspecUtils.compareDependencies(
          currentPubspec,
          previousPubspec,
          logger: logger,
        );

        expect(changes.hasChanges, isFalse);
        expect(changes.added, isEmpty);
        expect(changes.removed, isEmpty);
        expect(changes.modified, isEmpty);
      });
    });

    group('DependencyChanges', () {
      test('allChangedDependencies returns all dependency names', () {
        final changes = DependencyChanges();
        changes.added.add(DependencyChange(
          name: 'http',
          currentVersion: '^1.0.0',
          previousVersion: null,
          isDev: false,
        ));
        changes.removed.add(DependencyChange(
          name: 'dio',
          currentVersion: null,
          previousVersion: '^4.0.0',
          isDev: false,
        ));
        changes.modified.add(DependencyChange(
          name: 'test',
          currentVersion: '^1.1.0',
          previousVersion: '^1.0.0',
          isDev: true,
        ));

        final allChanges = changes.allChangedDependencies;
        expect(allChanges, containsAll(['http', 'dio', 'test']));
        expect(allChanges, hasLength(3));
      });
    });

    group('DependencyChange', () {
      test('toString formats correctly for added dependency', () {
        final change = DependencyChange(
          name: 'http',
          currentVersion: '^1.0.0',
          previousVersion: null,
          isDev: false,
        );

        expect(change.toString(), equals('http: added (^1.0.0)'));
      });

      test('toString formats correctly for removed dependency', () {
        final change = DependencyChange(
          name: 'dio',
          currentVersion: null,
          previousVersion: '^4.0.0',
          isDev: false,
        );

        expect(change.toString(), equals('dio: removed (^4.0.0)'));
      });

      test('toString formats correctly for modified dependency', () {
        final change = DependencyChange(
          name: 'test',
          currentVersion: '^1.1.0',
          previousVersion: '^1.0.0',
          isDev: true,
        );

        expect(change.toString(), equals('test: ^1.0.0 -> ^1.1.0'));
      });
    });
  });
}