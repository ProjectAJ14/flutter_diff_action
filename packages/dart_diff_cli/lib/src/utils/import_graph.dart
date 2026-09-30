import 'dart:convert';
import 'dart:io';

// `import`, `export` and `part` directives, including conditional imports.
// `part of` points back at the library, which is not a dependency.
final _directive = RegExp(
  r'^\s*(?:import|export|part(?!\s+of\b))\b([^;]*);',
  multiLine: true,
);
final _quoted = RegExp('[\'"]([^\'"]+)[\'"]');

/// The directories of a package whose Dart files are followed.
const _roots = ['lib', 'bin', 'test', 'integration_test', 'test_driver'];

/// Returns the Dart files of the current package (under `lib/`, `test/`,
/// `bin/`, ...) that import, export or include as a part one of [changed],
/// directly or through other files.
///
/// Imports are followed into other local packages (the workspace, path
/// dependencies), resolved with `.dart_tool/package_config.json`, so a test
/// that uses a changed file of another package is found too. Without a
/// package config, only `package:` imports of this package are followed.
///
/// [changed] and the result are paths relative to the current directory.
Set<String> dependentFiles(Iterable<String> changed) {
  final cwd = Directory.current.uri;
  final resolve = _resolver(cwd);

  final dependents = <Uri, Set<Uri>>{};
  final queue = [
    for (final root in _roots)
      if (Directory.fromUri(cwd.resolve('$root/')).existsSync())
        for (final entity in Directory.fromUri(cwd.resolve('$root/'))
            .listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart')) entity.uri,
  ];
  final seen = {...queue};
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    final String source;
    try {
      source = File.fromUri(file).readAsStringSync();
    } on Exception {
      continue; // Deleted, or not UTF-8.
    }
    for (final directive in _directive.allMatches(source)) {
      for (final uri in _quoted.allMatches(directive[1]!)) {
        final dependency = resolve(file, uri[1]!);
        if (dependency == null) continue;
        dependents.putIfAbsent(dependency, () => {}).add(file);
        if (seen.add(dependency)) queue.add(dependency);
      }
    }
  }

  final affected = <Uri>{};
  final todo = [for (final path in changed) cwd.resolve(path)];
  while (todo.isNotEmpty) {
    for (final file in dependents[todo.removeLast()] ?? const <Uri>{}) {
      if (affected.add(file)) todo.add(file);
    }
  }
  final prefix = cwd.toString();
  return {
    for (final file in affected)
      if (file.toString().startsWith(prefix))
        Uri.decodeComponent(file.toString().substring(prefix.length)),
  };
}

/// Returns a function resolving a directive's [uri] in the file [from] to
/// a local file, or null for `dart:` and hosted or SDK packages.
Uri? Function(Uri from, String uri) _resolver(Uri cwd) {
  final packages = <String, Uri>{}; // Local package name -> its lib/ dir.
  for (var dir = cwd;; dir = dir.resolve('..')) {
    final config = dir.resolve('.dart_tool/package_config.json');
    final file = File.fromUri(config);
    if (file.existsSync()) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      for (final package in json['packages'] as List<Object?>) {
        package as Map<String, Object?>;
        final root = package['rootUri'] as String;
        // Hosted and SDK packages have absolute file: URIs.
        if (Uri.parse(root).hasScheme) continue;
        packages[package['name'] as String] = config
            .resolve(root.endsWith('/') ? root : '$root/')
            .resolve(package['packageUri'] as String);
      }
      break;
    }
    if (dir.resolve('..') == dir) break;
  }
  if (packages.isEmpty) {
    final pubspec =
        File.fromUri(cwd.resolve('pubspec.yaml')).readAsStringSync();
    final name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    if (name != null) packages[name[1]!] = cwd.resolve('lib/');
  }

  return (from, uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return null;
    if (parsed.isScheme('package')) {
      return packages[parsed.pathSegments.firstOrNull]
          ?.resolve(parsed.pathSegments.skip(1).join('/'));
    }
    return parsed.hasScheme ? null : from.resolveUri(parsed);
  };
}
