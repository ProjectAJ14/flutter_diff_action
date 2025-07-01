import 'dart:io';

import 'package:dart_diff_cli/src/utils/common_utils.dart';
import 'package:mason_logger/mason_logger.dart';

/// Utility class for analyzing Dart files and mapping dependencies to their usage.
class DependencyAnalyzer {
  /// Finds all Dart files that import the specified dependencies.
  ///
  /// [dependencyNames] is the set of dependency names to search for.
  /// [searchPaths] is the list of directories to search in (default: ['lib/', 'test/']).
  /// [logger] is the logger instance.
  ///
  /// Returns a map of dependency names to lists of files that use them.
  static Map<String, List<String>> findFilesUsingDependencies(
    Set<String> dependencyNames, {
    List<String> searchPaths = const ['lib/', 'test/'],
    required Logger logger,
  }) {
    final Map<String, List<String>> result = {};
    
    // Initialize result map
    for (final dep in dependencyNames) {
      result[dep] = [];
    }
    
    logger.detail('Analyzing dependencies: ${dependencyNames.join(', ')}');
    logger.detail('Search paths: ${searchPaths.join(', ')}');
    
    // Find all Dart files in search paths
    final dartFiles = _findDartFiles(searchPaths, logger: logger);
    logger.detail('Found ${dartFiles.length} Dart files to analyze');
    
    // Analyze each file
    for (final filePath in dartFiles) {
      final imports = _extractImports(filePath, logger: logger);
      
      for (final import in imports) {
        final packageName = _extractPackageName(import);
        if (packageName != null && dependencyNames.contains(packageName)) {
          result[packageName]!.add(filePath);
          logger.detail('  - $filePath uses $packageName');
        }
      }
    }
    
    // Log summary
    for (final entry in result.entries) {
      if (entry.value.isNotEmpty) {
        logger.info('Dependency ${entry.key} is used by ${entry.value.length} files');
      }
    }
    
    return result;
  }

  /// Finds all Dart files in the specified search paths.
  static List<String> _findDartFiles(
    List<String> searchPaths, {
    required Logger logger,
  }) {
    final List<String> dartFiles = [];
    
    for (final searchPath in searchPaths) {
      final dir = Directory(searchPath);
      if (!dir.existsSync()) {
        logger.detail('Search path does not exist: $searchPath');
        continue;
      }
      
      try {
        final files = dir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.path.withUnixPath())
            .toList();
        
        dartFiles.addAll(files);
        logger.detail('Found ${files.length} Dart files in $searchPath');
      } catch (e) {
        logger.warn('Error scanning directory $searchPath: $e');
      }
    }
    
    return dartFiles;
  }

  /// Extracts import statements from a Dart file.
  static List<String> _extractImports(String filePath, {required Logger logger}) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return [];
      }
      
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final List<String> imports = [];
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        // Skip comments and empty lines
        if (trimmed.isEmpty || trimmed.startsWith('//')) {
          continue;
        }
        
        // Stop at the first non-import/export statement (optimization)
        if (!trimmed.startsWith('import ') && 
            !trimmed.startsWith('export ') && 
            !trimmed.startsWith('library ') &&
            !trimmed.startsWith('part ') &&
            imports.isNotEmpty) {
          break;
        }
        
        // Extract import statements
        if (trimmed.startsWith('import ')) {
          final importMatch = RegExp(r"import\s+['\"]([^'\"]+)['\"]").firstMatch(trimmed);
          if (importMatch != null) {
            imports.add(importMatch.group(1)!);
          }
        }
      }
      
      return imports;
    } catch (e) {
      logger.detail('Error reading file $filePath: $e');
      return [];
    }
  }

  /// Extracts the package name from an import statement.
  ///
  /// Examples:
  /// - 'package:http/http.dart' -> 'http'
  /// - 'package:flutter/material.dart' -> 'flutter'
  /// - 'dart:io' -> null (dart core library)
  /// - 'relative_file.dart' -> null (relative import)
  static String? _extractPackageName(String import) {
    if (import.startsWith('package:')) {
      final parts = import.substring(8).split('/');
      return parts.isNotEmpty ? parts.first : null;
    }
    return null;
  }

  /// Gets the corresponding test files for a list of source files.
  ///
  /// [sourceFiles] is the list of source file paths.
  /// [logger] is the logger instance.
  ///
  /// Returns a list of test file paths that exist.
  static List<String> getCorrespondingTestFiles(
    List<String> sourceFiles, {
    required Logger logger,
  }) {
    final List<String> testFiles = [];
    
    for (final sourceFile in sourceFiles) {
      // Skip if it's already a test file
      if (sourceFile.endsWith('_test.dart')) {
        testFiles.add(sourceFile);
        continue;
      }
      
      final testFile = calculateTestFile(sourceFile);
      if (File(testFile).existsSync()) {
        testFiles.add(testFile);
        logger.detail('Found test file: $testFile for $sourceFile');
      } else {
        logger.detail('No test file found for $sourceFile');
      }
    }
    
    return testFiles;
  }

  /// Gets files affected by dependency changes in a specific package context.
  ///
  /// [dependencyNames] is the set of changed dependency names.
  /// [packageRoot] is the root directory of the package (where pubspec.yaml is located).
  /// [includeTests] whether to include corresponding test files.
  /// [logger] is the logger instance.
  ///
  /// Returns a list of file paths that are affected by the dependency changes.
  static List<String> getAffectedFiles(
    Set<String> dependencyNames,
    String packageRoot, {
    bool includeTests = true,
    required Logger logger,
  }) {
    final currentDir = Directory.current.path;
    
    try {
      // Change to package directory
      Directory.current = Directory(packageRoot);
      
      final searchPaths = <String>[];
      
      // Add lib directory if it exists
      if (Directory('lib').existsSync()) {
        searchPaths.add('lib/');
      }
      
      // Add test directory if it exists and we want to include tests
      if (includeTests && Directory('test').existsSync()) {
        searchPaths.add('test/');
      }
      
      if (searchPaths.isEmpty) {
        logger.warn('No lib/ or test/ directories found in $packageRoot');
        return [];
      }
      
      final usageMap = findFilesUsingDependencies(
        dependencyNames,
        searchPaths: searchPaths,
        logger: logger,
      );
      
      final Set<String> affectedFiles = {};
      
      for (final fileList in usageMap.values) {
        affectedFiles.addAll(fileList);
      }
      
      List<String> result = affectedFiles.toList();
      
      // If we want tests but haven't included test directory, find corresponding test files
      if (includeTests && !searchPaths.contains('test/')) {
        final testFiles = getCorrespondingTestFiles(result, logger: logger);
        result.addAll(testFiles);
      }
      
      // Convert to relative paths from the original working directory
      final packageRootPath = Directory(packageRoot).absolute.path.withUnixPath();
      result = result.map((file) {
        final absolutePath = Directory(file).absolute.path.withUnixPath();
        if (absolutePath.startsWith(packageRootPath)) {
          return absolutePath.substring(packageRootPath.length + 1);
        }
        return file;
      }).toList();
      
      return result;
    } finally {
      // Restore original directory
      Directory.current = Directory(currentDir);
    }
  }
}