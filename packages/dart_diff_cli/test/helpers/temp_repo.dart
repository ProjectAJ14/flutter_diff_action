import 'dart:io';

import 'package:test/test.dart';

/// A temporary git repository on `main` with one commit, pushed to a bare
/// `origin` next to it so `git fetch origin main` works offline.
class TempRepo {
  TempRepo() {
    final tmp = Directory.systemTemp.createTempSync('dart_diff_test');
    dir = Directory('${tmp.path}/repo')..createSync();
    git(['init', '-q', '-b', 'main']);
    write('pubspec.yaml', 'name: repo');
    write('lib/a.dart', 'void a() {}');
    write('packages/pkg/lib/b.dart', 'void b() {}');
    git(['add', '.']);
    git(['commit', '-qm', 'init']);
    Process.runSync(
      'git',
      ['clone', '-q', '--bare', dir.path, 'origin'],
      workingDirectory: tmp.path,
    );
    git(['remote', 'add', 'origin', '${tmp.path}/origin']);
    git(['fetch', '-q', 'origin']);
  }

  late final Directory dir;

  void git(List<String> args) {
    final result = Process.runSync(
      'git',
      ['-c', 'user.email=t@t', '-c', 'user.name=t', ...args],
      workingDirectory: dir.path,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  void write(String path, String content) =>
      (File('${dir.path}/$path')..createSync(recursive: true))
          .writeAsStringSync(content);

  void delete() => dir.parent.deleteSync(recursive: true);
}
