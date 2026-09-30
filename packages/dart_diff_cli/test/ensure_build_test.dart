@Tags(['version-verify'])
library;

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ensure_build',
    () => expectBuildClean(packageRelativeDirectory: 'packages/dart_diff_cli'),
    timeout: const Timeout.factor(4),
  );
}
