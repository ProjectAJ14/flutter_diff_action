import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

const _cliDirectory = 'packages/dart_diff_cli';

void main() async {
  final logger = Logger();
  logger.info('Starting version update process');

  try {
    // Read the pubspec.yaml file
    final pubspecFile = File('$_cliDirectory/pubspec.yaml');
    logger.info('Reading pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(pubspecContent);

    // Get the current version
    final version = pubspec.version.toString();
    logger.info('Current version: $version');

    // Update the version.dart file. Content must match what build_version
    // generates, or the ensure_build test fails.
    final versionFile = File('$_cliDirectory/lib/src/version.dart');
    logger.info('Updating ${versionFile.path}');
    await versionFile.writeAsString('''
// Generated code. Do not modify.
const packageVersion = '$version';
''');

    // Runs as the Melos preCommit hook, which only stages pubspec.yaml and
    // CHANGELOG.md, so stage version.dart for the release commit and tag.
    final add = await Process.run('git', ['add', versionFile.path]);
    if (add.exitCode != 0) throw Exception(add.stderr);
    logger.success('Updated ${versionFile.path} to $version');
  } catch (e) {
    logger.err('An error occurred while updating the version $e');
    exit(1);
  }
}
