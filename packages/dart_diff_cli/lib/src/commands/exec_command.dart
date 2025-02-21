import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class ExecCommand extends Command<int> {
  ExecCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        'branch',
        abbr: 'b',
        help: 'Specify the base branch to use for git diff',
        defaultsTo: 'main',
      )
      ..addOption(
        'remote',
        abbr: 'r',
        defaultsTo: 'origin',
        help: 'Specify the remote repository to use for git diff',
      )
      ..addFlag(
        'flutter',
        abbr: 'f',
        help: 'Run flutter test instead of dart test',
      );
  }

  @override
  String get description => 'A exec command that just prints one joke';

  @override
  String get name => 'exec';

  final Logger _logger;

  @override
  Future<int> run() async {
    _logger.info(
        'Why did the scarecrow win an award? Because he was outstanding in his field!');
    _logger.info('This is a joke, but the command is working');
    _logger.info('args: ${argResults?.arguments.join(', ')}');
    return 0;
  }
}
