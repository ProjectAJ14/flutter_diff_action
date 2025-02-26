import 'package:args/args.dart';

enum Options {
  branch('main', 'b'),
  remote('origin', 'r');

  final String defaultVal, abbr;

  const Options(this.defaultVal, this.abbr);

  String parsedValue(ArgResults args) => args.option(name) ?? defaultVal;
}
