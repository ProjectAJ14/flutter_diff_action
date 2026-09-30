# [2.2.0](https://github.com/ProjectAJ14/flutter_diff_action/compare/v2.1.0...v2.2.0) (2026-09-30)


### Features

* **cli:** report a full run when every test is selected ([47a7b69](https://github.com/ProjectAJ14/flutter_diff_action/commit/47a7b692e44af84c894912657e02bd827858deed))


### Performance Improvements

* **action:** resolve the CLI without its dev dependencies ([71695ed](https://github.com/ProjectAJ14/flutter_diff_action/commit/71695ed582c6990aeb9c32c1249e951ce25dab5a))
* deepen a shallow clone by 1 before 100 commits ([cfd064a](https://github.com/ProjectAJ14/flutter_diff_action/commit/cfd064a30986ed5da3e29e9377d8f4922e1f3aa4))

# [2.1.0](https://github.com/ProjectAJ14/flutter_diff_action/compare/v2.0.0...v2.1.0) (2026-09-30)


### Features

* base per event, melos dependents, outputs and job summary ([600c7e7](https://github.com/ProjectAJ14/flutter_diff_action/commit/600c7e728e4a89e217de6887af0e8239d0e1379c)), closes [#25](https://github.com/ProjectAJ14/flutter_diff_action/issues/25) [#26](https://github.com/ProjectAJ14/flutter_diff_action/issues/26)
* **cli:** pick tests through the import graph, add modes, base and reports ([f64008f](https://github.com/ProjectAJ14/flutter_diff_action/commit/f64008f28a2cb4015fc9c7199fac34dff238acf6)), closes [#25](https://github.com/ProjectAJ14/flutter_diff_action/issues/25) [#26](https://github.com/ProjectAJ14/flutter_diff_action/issues/26)

# [2.0.0](https://github.com/ProjectAJ14/flutter_diff_action/compare/v1.0.1...v2.0.0) (2026-09-30)


* feat!: install the CLI from the action's own checkout ([4359df1](https://github.com/ProjectAJ14/flutter_diff_action/commit/4359df1e295ceb5f74ac784c2a8c937064818e2b))
* feat(dart_diff_cli)!: fix diff detection, stream output, propagate exit codes ([9d93230](https://github.com/ProjectAJ14/flutter_diff_action/commit/9d93230e4c8f51dfbee4661178d190fa42bc78d4))


### Bug Fixes

* correct logger success message placement in update_cli_version.dart ([eefb01e](https://github.com/ProjectAJ14/flutter_diff_action/commit/eefb01e1668e01e797ea3c5bcf75eab91baee805))
* **dart_diff_cli:** parse exec options only before the command ([d19f19a](https://github.com/ProjectAJ14/flutter_diff_action/commit/d19f19a7d3219b78deb13ba0a79d3e4c25c0fee1))
* keep shell quoting in the action command input ([37f3426](https://github.com/ProjectAJ14/flutter_diff_action/commit/37f34269023ffc02f347fee826745b2c5b2f4862))
* run the version hook without a global melos ([73a7c56](https://github.com/ProjectAJ14/flutter_diff_action/commit/73a7c567ad3a8348c589f5c24d4cf46bfbb251d1))
* sync version.dart before melos tags the release ([441cbd6](https://github.com/ProjectAJ14/flutter_diff_action/commit/441cbd6e3279479724859b68613413a64fd15223))


### Features

* add SVG icon for Dart Diff CLI and update README with logo ([65c5442](https://github.com/ProjectAJ14/flutter_diff_action/commit/65c544223c1fe776ea53215876c0565a9aebf586))


### BREAKING CHANGES

* failing commands now fail the step, and the CLI is no
longer installed from pub.dev.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
* exec now exits with the wrapped command's exit code and
diffs against the merge base instead of the base branch tip.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## [1.0.1](https://github.com/ProjectAJ14/flutter_diff_action/compare/v1.0.0...v1.0.1) (2025-02-28)


### Bug Fixes

* update dart_diff_cli activation command in action.yaml ([ec49ab6](https://github.com/ProjectAJ14/flutter_diff_action/commit/ec49ab6c786e7d13262e3ad14c1836a6f678bbcf))

# 1.0.0 (2025-02-28)


### Bug Fixes

* added working-dir support for providing directory ([e0ee316](https://github.com/ProjectAJ14/flutter_diff_action/commit/e0ee316d9a7dd790da69c565ad5c4c25efe4cfab))
* Rename test workflow file for consistency ([9848fbd](https://github.com/ProjectAJ14/flutter_diff_action/commit/9848fbd5b7a824448032fb9c8e714f5c42c14d43))
* test_action jobs ([4a9ea3c](https://github.com/ProjectAJ14/flutter_diff_action/commit/4a9ea3c186905d69776f95dfcb1bf0cc5670cdd1))
* Update conditional check for USE_MELOS in diff_command.sh ([f46890d](https://github.com/ProjectAJ14/flutter_diff_action/commit/f46890d2b2a9dce702ed14c332f7a625dc04fa60))
* update default base branch from staging to main ([3163905](https://github.com/ProjectAJ14/flutter_diff_action/commit/31639059bac4a65e7521f126ab22c24d4d49c63b))
* Update path for diff_command.sh in action.yaml ([3eb718f](https://github.com/ProjectAJ14/flutter_diff_action/commit/3eb718f1f779ad68186c3417a461916056f775f8))


### Features

* add branch and remote inputs to action.yaml for enhanced command flexibility ([3e3ad13](https://github.com/ProjectAJ14/flutter_diff_action/commit/3e3ad13466c55e4ead4fe880a9a387c57418196d))
* Add debug option to test workflow for improved troubleshooting ([b353e80](https://github.com/ProjectAJ14/flutter_diff_action/commit/b353e80c17377818e3b754cf3e4b3e65ca6b0e5b))
* Add initial implementation of Flutter Diff Action with README, action configuration, and tests ([f4240e2](https://github.com/ProjectAJ14/flutter_diff_action/commit/f4240e2932aa0c961f489b7444108bfbfac56dc0))
* add main entry point ([6914dfe](https://github.com/ProjectAJ14/flutter_diff_action/commit/6914dfec191c6d527c07e042c270169a82d07618))
* add pubspec.lock to .gitignore for Dart package management ([2a7a822](https://github.com/ProjectAJ14/flutter_diff_action/commit/2a7a822a0675ce62680658b161e6be95f41d1a7a))
* added dart_diff support ([8d46a4b](https://github.com/ProjectAJ14/flutter_diff_action/commit/8d46a4b97ca457223bcdc8d0127f068e0a1a3ef0))
* added dart_diff_cli template and .gitignore, enhance action.yaml descriptions ([8d44dca](https://github.com/ProjectAJ14/flutter_diff_action/commit/8d44dcabc43c693daf71c87dbada7e13519e726e))
* added dart-diff in action.yml ([6259d48](https://github.com/ProjectAJ14/flutter_diff_action/commit/6259d48d2b5e9d529d3c778ebe245dbff13166bc))
* added example folder ([1ca9dc0](https://github.com/ProjectAJ14/flutter_diff_action/commit/1ca9dc0db06ebb9420685f48f0ff3e3bdca14b31))
* added use-melos support ([71896c8](https://github.com/ProjectAJ14/flutter_diff_action/commit/71896c8147b0ece2a527085f57f1b44479781aef))
* enhance CI workflow by adding base branch fetch and restructuring test actions ([81d2e98](https://github.com/ProjectAJ14/flutter_diff_action/commit/81d2e9861c7b52db0d926cb3edeca1d8c2b07822))
* enhance CI workflow with new test jobs and improved structure ([f6dbded](https://github.com/ProjectAJ14/flutter_diff_action/commit/f6dbded976dcf703f227a709c62b2c7a6471cc4a))
* Enhance diff_command.sh with debug option and improved parameter validation ([adbd0a0](https://github.com/ProjectAJ14/flutter_diff_action/commit/adbd0a014b8792a29f980f87927410f5b5384559))
* enhance logging and error handling in git utility functions ([62edd06](https://github.com/ProjectAJ14/flutter_diff_action/commit/62edd06db5b48b50a3377db0d7c46305e1f00931))
* expand .gitignore for Dart/Flutter and IDE specific files ([ee88b65](https://github.com/ProjectAJ14/flutter_diff_action/commit/ee88b65e1876297f296f1952c820a58ccfe5427d))
* implemented exec command running logic ([b5aba49](https://github.com/ProjectAJ14/flutter_diff_action/commit/b5aba49244fe75c48d2007ef8ea912bb740c117a))
* improved clarity and structure, remove flutter flag from exec command options ([1e80fbd](https://github.com/ProjectAJ14/flutter_diff_action/commit/1e80fbdc19b1b36a2ec97580a0f52de7bee95e87))
* refactor command execution and logging for improved clarity ([fd7ea62](https://github.com/ProjectAJ14/flutter_diff_action/commit/fd7ea62140da550384c96304ad4665e895adb631))
* refactor command structure and update action.yaml for exec command ([5dfccb6](https://github.com/ProjectAJ14/flutter_diff_action/commit/5dfccb6674844d5e7fc86fcb60e9b8a805158006))
* update action.yaml to activate dart_diff_cli ([b6eeac7](https://github.com/ProjectAJ14/flutter_diff_action/commit/b6eeac7f874279b9833e0382c23dc17b4367d3ff))
* update melos command to use diff syntax for improved branch comparison ([1ef55ed](https://github.com/ProjectAJ14/flutter_diff_action/commit/1ef55ed94588de62a13aa4fb1ec4732fa76ea074))
* update README with examples ([a9fe764](https://github.com/ProjectAJ14/flutter_diff_action/commit/a9fe7649ce138f8f503136b15bf0ecbd4ae7c17d))

# 1.0.0-alpha.1 (2025-02-16)


### Bug Fixes

* Rename test workflow file for consistency ([9848fbd](https://github.com/ProjectAJ14/flutter_diff_action/commit/9848fbd5b7a824448032fb9c8e714f5c42c14d43))
* Update conditional check for USE_MELOS in diff_command.sh ([f46890d](https://github.com/ProjectAJ14/flutter_diff_action/commit/f46890d2b2a9dce702ed14c332f7a625dc04fa60))
* Update path for diff_command.sh in action.yaml ([3eb718f](https://github.com/ProjectAJ14/flutter_diff_action/commit/3eb718f1f779ad68186c3417a461916056f775f8))


### Features

* Add debug option to test workflow for improved troubleshooting ([b353e80](https://github.com/ProjectAJ14/flutter_diff_action/commit/b353e80c17377818e3b754cf3e4b3e65ca6b0e5b))
* Add initial implementation of Flutter Diff Action with README, action configuration, and tests ([f4240e2](https://github.com/ProjectAJ14/flutter_diff_action/commit/f4240e2932aa0c961f489b7444108bfbfac56dc0))
* Enhance diff_command.sh with debug option and improved parameter validation ([adbd0a0](https://github.com/ProjectAJ14/flutter_diff_action/commit/adbd0a014b8792a29f980f87927410f5b5384559))

# 1.0.0-dev-semantic-release.1 (2025-02-16)


### Bug Fixes

* Rename test workflow file for consistency ([9848fbd](https://github.com/ProjectAJ14/flutter_diff_action/commit/9848fbd5b7a824448032fb9c8e714f5c42c14d43))
* Update conditional check for USE_MELOS in diff_command.sh ([f46890d](https://github.com/ProjectAJ14/flutter_diff_action/commit/f46890d2b2a9dce702ed14c332f7a625dc04fa60))
* Update path for diff_command.sh in action.yaml ([3eb718f](https://github.com/ProjectAJ14/flutter_diff_action/commit/3eb718f1f779ad68186c3417a461916056f775f8))


### Features

* Add debug option to test workflow for improved troubleshooting ([b353e80](https://github.com/ProjectAJ14/flutter_diff_action/commit/b353e80c17377818e3b754cf3e4b3e65ca6b0e5b))
* Add initial implementation of Flutter Diff Action with README, action configuration, and tests ([f4240e2](https://github.com/ProjectAJ14/flutter_diff_action/commit/f4240e2932aa0c961f489b7444108bfbfac56dc0))
* Enhance diff_command.sh with debug option and improved parameter validation ([adbd0a0](https://github.com/ProjectAJ14/flutter_diff_action/commit/adbd0a014b8792a29f980f87927410f5b5384559))
