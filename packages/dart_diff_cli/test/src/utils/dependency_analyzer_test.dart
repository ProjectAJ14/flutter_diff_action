import 'dart:io';

import 'package:dart_diff_cli/src/utils/dependency_analyzer.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

void main() {
  group('DependencyAnalyzer', () {
    late Logger logger;
    late Directory tempDir;

    setUp(() async {
      logger = Logger(level: Level.quiet);
      tempDir = await Directory.systemTemp.createTemp('dependency_analyzer_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('findFilesUsingDependencies', () {
      test('finds files that import specified packages', () async {
        // Create test files
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);
        
        final mainFile = File('${libDir.path}/main.dart');
        await mainFile.writeAsString('''
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() {}
''');

        final utilsFile = File('${libDir.path}/utils.dart');
        await utilsFile.writeAsString('''
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';

class Utils {}
''');

        final noImportsFile = File('${libDir.path}/no_imports.dart');
        await noImportsFile.writeAsString('''
class NoImports {}
''');

        // Change to temp directory
        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.findFilesUsingDependencies(
            {'flutter', 'http', 'dio', 'nonexistent'},
            searchPaths: ['lib/'],
            logger: logger,
          );

          expect(result['flutter'], hasLength(2));
          expect(result['flutter'], containsAll(['lib/main.dart', 'lib/utils.dart']));
          
          expect(result['http'], hasLength(1));
          expect(result['http'], contains('lib/main.dart'));
          
          expect(result['dio'], hasLength(1));
          expect(result['dio'], contains('lib/utils.dart'));
          
          expect(result['nonexistent'], isEmpty);
        } finally {
          Directory.current = originalDir;
        }
      });

      test('handles files with no imports', () async {
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);
        
        final emptyFile = File('${libDir.path}/empty.dart');
        await emptyFile.writeAsString('class Empty {}');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.findFilesUsingDependencies(
            {'flutter'},
            searchPaths: ['lib/'],
            logger: logger,
          );

          expect(result['flutter'], isEmpty);
        } finally {
          Directory.current = originalDir;
        }
      });

      test('ignores dart core libraries', () async {
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);
        
        final mainFile = File('${libDir.path}/main.dart');
        await mainFile.writeAsString('''
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {}
''');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.findFilesUsingDependencies(
            {'dart', 'flutter'},
            searchPaths: ['lib/'],
            logger: logger,
          );

          expect(result['dart'], isEmpty);
          expect(result['flutter'], hasLength(1));
        } finally {
          Directory.current = originalDir;
        }
      });

      test('ignores relative imports', () async {
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);
        
        final mainFile = File('${libDir.path}/main.dart');
        await mainFile.writeAsString('''
import 'utils.dart';
import '../config.dart';
import 'package:flutter/material.dart';

void main() {}
''');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.findFilesUsingDependencies(
            {'utils', 'config', 'flutter'},
            searchPaths: ['lib/'],
            logger: logger,
          );

          expect(result['utils'], isEmpty);
          expect(result['config'], isEmpty);
          expect(result['flutter'], hasLength(1));
        } finally {
          Directory.current = originalDir;
        }
      });
    });

    group('getCorrespondingTestFiles', () {
      test('finds existing test files for source files', () async {
        final libDir = Directory('${tempDir.path}/lib');
        final testDir = Directory('${tempDir.path}/test');
        await libDir.create(recursive: true);
        await testDir.create(recursive: true);

        // Create source files
        await File('${libDir.path}/main.dart').writeAsString('void main() {}');
        await File('${libDir.path}/utils.dart').writeAsString('class Utils {}');

        // Create corresponding test files
        await File('${testDir.path}/main_test.dart').writeAsString('void main() {}');
        // Note: utils_test.dart doesn't exist

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.getCorrespondingTestFiles(
            ['lib/main.dart', 'lib/utils.dart'],
            logger: logger,
          );

          expect(result, hasLength(1));
          expect(result, contains('test/main_test.dart'));
        } finally {
          Directory.current = originalDir;
        }
      });

      test('includes test files that are already test files', () async {
        final testDir = Directory('${tempDir.path}/test');
        await testDir.create(recursive: true);

        await File('${testDir.path}/main_test.dart').writeAsString('void main() {}');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final result = DependencyAnalyzer.getCorrespondingTestFiles(
            ['test/main_test.dart'],
            logger: logger,
          );

          expect(result, hasLength(1));
          expect(result, contains('test/main_test.dart'));
        } finally {
          Directory.current = originalDir;
        }
      });
    });
  });
}