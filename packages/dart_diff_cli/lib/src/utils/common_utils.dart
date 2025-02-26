import 'dart:io';

String runCommand(List<String> command, {bool output = true}) {
  if (output) {
    print('Running: ${command.join(' ')}');
  }
  final result = Process.runSync(
    command.first,
    command.sublist(1),
    workingDirectory: Directory.current.path,
  );
  if (result.exitCode != 0) {
    print('Error running ${command.sublist(0, 2).join(' ')} ${result.stderr}');
    exit(1);
  }
  if (output) {
    stdout.write(result.stdout);
  }
  return result.stdout.toString();
}

bool isFlutterProjectRoot() {
  return File('pubspec.yaml').existsSync();
}

String calculateTestFile(String filePath) {
  if (filePath.startsWith('lib/')) {
    return filePath
        .replaceFirst('lib/', 'test/')
        .replaceAll('.dart', '_test.dart');
  }
  return filePath.replaceAll('.dart', '_test.dart');
}

extension StringExtension on String {
  String withoutBasePath(String path) => replaceFirst(
        '${path.withUnixPath()}/',
        '',
      );

  String withUnixPath() => replaceAll('\\', '/');

  String withWindowsPath() => replaceAll('/', '\\');

  String withPlatformPath() => Platform.isWindows ? withWindowsPath() : this;
}
