import 'dart:io';

import 'package:dart_diff_cli/src/utils/common_utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

/// Utility class for parsing and comparing pubspec.yaml files.
class PubspecUtils {
  /// Gets all pubspec.yaml files in the current git repository.
  ///
  /// Returns a list of pubspec.yaml file paths relative to the git root.
  static List<String> getAllPubspecFiles({required Logger logger}) {
    final result = runCommand(
      ['find', '.', '-name', 'pubspec.yaml', '-type', 'f'],
      logger: logger,
    );
    
    return result
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((path) => path.replaceFirst('./', ''))
        .toList();
  }

  /// Gets the list of changed pubspec.yaml files from git diff.
  ///
  /// [modifiedFiles] is the list of all modified files from git diff.
  ///
  /// Returns a list of pubspec.yaml file paths that have been modified.
  static List<String> getChangedPubspecFiles(
    List<String> modifiedFiles, {
    required Logger logger,
  }) {
    final changedPubspecs = modifiedFiles
        .where((file) => file.endsWith('pubspec.yaml'))
        .toList();
    
    logger.detail('Found ${changedPubspecs.length} changed pubspec files');
    for (final file in changedPubspecs) {
      logger.detail('  - $file');
    }
    
    return changedPubspecs;
  }

  /// Parses a pubspec.yaml file at the given path.
  ///
  /// [filePath] is the path to the pubspec.yaml file.
  ///
  /// Returns the parsed [Pubspec] object, or null if parsing fails.
  static Pubspec? parsePubspec(String filePath, {required Logger logger}) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        logger.warn('Pubspec file does not exist: $filePath');
        return null;
      }
      
      final content = file.readAsStringSync();
      return Pubspec.parse(content);
    } catch (e) {
      logger.warn('Failed to parse pubspec at $filePath: $e');
      return null;
    }
  }

  /// Gets the content of a pubspec.yaml file from a specific git revision.
  ///
  /// [filePath] is the path to the pubspec.yaml file.
  /// [revision] is the git revision (e.g., 'origin/main', 'HEAD~1').
  ///
  /// Returns the pubspec content as a string, or null if not found.
  static String? getPubspecFromRevision(
    String filePath,
    String revision, {
    required Logger logger,
  }) {
    try {
      final result = runCommand(
        ['git', 'show', '$revision:$filePath'],
        logger: logger,
      );
      return result;
    } catch (e) {
      logger.detail('Could not get pubspec from revision $revision:$filePath - $e');
      return null;
    }
  }

  /// Compares dependencies between two pubspec files.
  ///
  /// [currentPubspec] is the current pubspec.
  /// [previousPubspec] is the previous pubspec to compare against.
  ///
  /// Returns a [DependencyChanges] object containing the differences.
  static DependencyChanges compareDependencies(
    Pubspec currentPubspec,
    Pubspec previousPubspec, {
    required Logger logger,
  }) {
    final changes = DependencyChanges();
    
    // Compare regular dependencies
    _compareDependencyMaps(
      currentPubspec.dependencies,
      previousPubspec.dependencies,
      changes,
      isDev: false,
      logger: logger,
    );
    
    // Compare dev dependencies
    _compareDependencyMaps(
      currentPubspec.devDependencies,
      previousPubspec.devDependencies,
      changes,
      isDev: true,
      logger: logger,
    );
    
    logger.detail('Dependency changes: ${changes.added.length} added, '
        '${changes.removed.length} removed, ${changes.modified.length} modified');
    
    return changes;
  }

  /// Compares two dependency maps and populates the changes object.
  static void _compareDependencyMaps(
    Map<String, Dependency> current,
    Map<String, Dependency> previous,
    DependencyChanges changes, {
    required bool isDev,
    required Logger logger,
  }) {
    final currentKeys = current.keys.toSet();
    final previousKeys = previous.keys.toSet();
    
    // Find added dependencies
    final added = currentKeys.difference(previousKeys);
    for (final key in added) {
      changes.added.add(DependencyChange(
        name: key,
        currentVersion: _getDependencyVersion(current[key]!),
        previousVersion: null,
        isDev: isDev,
      ));
    }
    
    // Find removed dependencies
    final removed = previousKeys.difference(currentKeys);
    for (final key in removed) {
      changes.removed.add(DependencyChange(
        name: key,
        currentVersion: null,
        previousVersion: _getDependencyVersion(previous[key]!),
        isDev: isDev,
      ));
    }
    
    // Find modified dependencies
    final common = currentKeys.intersection(previousKeys);
    for (final key in common) {
      final currentVersion = _getDependencyVersion(current[key]!);
      final previousVersion = _getDependencyVersion(previous[key]!);
      
      if (currentVersion != previousVersion) {
        changes.modified.add(DependencyChange(
          name: key,
          currentVersion: currentVersion,
          previousVersion: previousVersion,
          isDev: isDev,
        ));
      }
    }
  }

  /// Extracts version string from a dependency.
  static String _getDependencyVersion(Dependency dependency) {
    if (dependency is HostedDependency) {
      return dependency.version.toString();
    } else if (dependency is GitDependency) {
      return '${dependency.url}@${dependency.ref ?? 'HEAD'}';
    } else if (dependency is PathDependency) {
      return 'path:${dependency.path}';
    } else if (dependency is SdkDependency) {
      return 'sdk:${dependency.sdk}';
    }
    return dependency.toString();
  }
}

/// Represents changes in dependencies between two pubspec files.
class DependencyChanges {
  /// Dependencies that were added.
  final List<DependencyChange> added = [];
  
  /// Dependencies that were removed.
  final List<DependencyChange> removed = [];
  
  /// Dependencies that were modified (version changed).
  final List<DependencyChange> modified = [];
  
  /// Returns true if there are any dependency changes.
  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty || modified.isNotEmpty;
  
  /// Returns all changed dependency names.
  Set<String> get allChangedDependencies {
    final Set<String> result = {};
    result.addAll(added.map((d) => d.name));
    result.addAll(removed.map((d) => d.name));
    result.addAll(modified.map((d) => d.name));
    return result;
  }
}

/// Represents a single dependency change.
class DependencyChange {
  /// The name of the dependency.
  final String name;
  
  /// The current version (null if removed).
  final String? currentVersion;
  
  /// The previous version (null if added).
  final String? previousVersion;
  
  /// Whether this is a dev dependency.
  final bool isDev;
  
  const DependencyChange({
    required this.name,
    required this.currentVersion,
    required this.previousVersion,
    required this.isDev,
  });
  
  @override
  String toString() {
    if (currentVersion == null) {
      return '$name: removed ($previousVersion)';
    } else if (previousVersion == null) {
      return '$name: added ($currentVersion)';
    } else {
      return '$name: $previousVersion -> $currentVersion';
    }
  }
}