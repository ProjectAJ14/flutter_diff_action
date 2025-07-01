import 'package:args/args.dart';

enum Options {
  branch('main', 'b'),
  remote('origin', 'r'),
  dependencyScanDepth('lib/,test/', 'd');

  final String defaultVal, abbr;

  const Options(this.defaultVal, this.abbr);

  String parsedValue(ArgResults args) => args.option(name) ?? defaultVal;
}

enum Flags {
  includeDependencyTests('include-dependency-tests', 'i');

  final String name, abbr;

  const Flags(this.name, this.abbr);

  bool parsedValue(ArgResults args) => args.flag(name);
}
