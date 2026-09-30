<p align="center">
  <a href="https://pub.dev/packages/dart_diff_cli">
    <img src="https://github.com/user-attachments/assets/2f925259-f0e2-448e-937e-22331f916d89" alt="Nonstop Logo" height="252" />
  </a>
  <p align="center">Optimizes Flutter/Dart development workflows by running commands only on changed files, significantly speeding up CI/CD pipelines and local development.</p>
</p>

[![dart_diff_cli](https://img.shields.io/pub/v/dart_diff_cli.svg?label=dart_diff_cli&logo=dart&color=blue&style=for-the-badge)](https://pub.dev/packages/dart_diff_cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A command-line interface for running Flutter and Dart commands efficiently on changed files.

## Table of Contents

- [Overview](#overview)
- [Commands](#commands)
  - [exec](#exec)
  - [update](#update)
- [Common Workflows](#common-workflows)
- [Global Options](#global-options)
- [Troubleshooting](#troubleshooting)

## Overview

The `dart_diff_cli` tool optimizes your Flutter/Dart development workflow by running commands only on files that have changed. This significantly speeds up testing, analysis, and formatting during development by focusing only on the files that matter.

Key features include:
- Running commands only on changed files
- Automatically identifying corresponding test files
- Supporting both standard projects and Melos-based mono-repos
- Providing detailed logging for troubleshooting



## Commands

### exec

Executes Flutter/Dart commands on changed files.

```bash
dart_diff exec [options] -- [command] [command-args]
```

### Alias
- ddf

```bash
ddf exec [options] -- [command] [command-args]
```

**Options:**

| Option          | Alias | Description                           | Default  |
|-----------------|-------|---------------------------------------|----------|
| `--branch`      | `-b`  | Base branch for comparison            | `main`   |
| `--remote`      | `-r`  | Remote repository name                | `origin` |
| `--[no-]fetch`  |       | Run `git fetch <remote> <branch>` first | on     |

`--branch` and `--remote` can't start with `-`.

**How files are picked:**

1. The changed files are those in `git diff --merge-base <remote>/<branch>` (or the diff against the branch tip when there is no merge base, e.g. in a shallow clone) plus untracked files. Paths are relative to, and limited to, the current directory, which must contain a `pubspec.yaml`.
2. A failed `git fetch` only prints a warning and uses the local `<remote>/<branch>`. Use `--no-fetch` when the ref is already up to date, e.g. after fetching once for every package of a mono-repo.
3. Only existing `.dart` files are passed to the command.
4. For test commands (`flutter test`, `dart test`, `fvm flutter test`), each file is replaced by its test: `lib/src/a.dart` -> `test/src/a_test.dart`, other files -> a `_test.dart` sibling, `_test.dart` files as they are.

**Full test suite:** for a test command, the command runs with no files (the whole suite) when:

- `pubspec.yaml`, `pubspec.lock`, `dart_test.yaml`, `build.yaml` or `l10n.yaml` at the project root changed,
- a file under `test/` that isn't a `_test.dart` changed (helpers, fixtures, goldens),
- a non-Dart file under `lib/` or `assets/` changed,
- a Dart file that isn't a `_test.dart` was deleted or renamed.

Otherwise, a changed file with no matching test file is skipped, and nothing runs if no changed file has a test.

**Long file lists:** the files are split over several runs of the command so each command line stays under the OS limit (6000 characters on Windows, leaving room for what `flutter.bat` adds to cmd.exe's 8191 limit). Every run happens, even after a failure. A test command that would need several runs runs the full suite once instead, so coverage and the test summary stay whole.

`exec` stops reading its own options at the first word of the command, so `--` is optional: `dart_diff exec -b develop flutter test --coverage` works too.

**Exit codes:**

| Code | Meaning |
|------|---------|
| `0`  | The command succeeded, or there was nothing to run |
| `1`  | No `pubspec.yaml`, no command given, not a git repository, or the diff failed |
| `64` | Invalid usage, e.g. an unknown option or a branch starting with `-` |
| `69` | `git` or the command could not be started |
| other | The command's own exit code (the first failing one when split over several runs) |

**Examples:**

**Run tests on changed files**

```bash
# Run tests on changed files compared to main branch
dart_diff exec -- flutter test

# Run tests against a different branch
dart_diff exec -b develop -- flutter test

# Run tests with verbose output
dart_diff --verbose exec -- flutter test
```

**Run analyzer on changed files**

```bash
# Run the analyzer on changed files
dart_diff exec -- dart analyze

# Run analyzer with specific options
dart_diff exec -- dart analyze --fatal-infos
```

**Format changed files**

```bash
# Format changed files
dart_diff exec -- dart format

# Format with specific options
dart_diff exec -- dart format --set-exit-if-changed
```

### update

Updates the dart_diff_cli to the latest version.

```bash
dart_diff update
```

The command:
1. Checks the current installed version
2. Compares it with the latest version available on pub.dev
3. Updates to the latest version if needed

## Common Workflows

### Speeding up test runs during development

```bash
# Run tests only on the modified files
dart_diff exec -- flutter test

# Run tests with coverage
dart_diff exec -- flutter test --coverage
```

### Pre-commit checks

```bash
# Format only changed files
dart_diff exec -- dart format --set-exit-if-changed

# Analyze only changed files
dart_diff exec -- dart analyze

# Run tests for changed files
dart_diff exec -- flutter test
```

### CI/CD optimization

```bash
# In your CI pipeline, compare against the target branch
dart_diff exec -b main -- flutter test --no-pub --coverage
```

When the `CI` environment variable is set, the pub.dev update check is skipped.

## Global Options

The following options can be used with any command:

| Option      | Alias | Description                                         |
|-------------|-------|-----------------------------------------------------|
| `--version` | `-v`  | Print the current version of the CLI                |
| `--verbose` |       | Enable verbose logging including all shell commands |
| `--help`    | `-h`  | Display help information for commands               |

## Troubleshooting

### Command Not Found

If the `dart_diff` command is not found after installation, ensure that your Dart SDK's bin directory is in your PATH.

For Unix-based systems:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

For Windows:
```bash
set PATH=%PATH%;%LOCALAPPDATA%\Pub\Cache\bin
```

### No Modified Dart Files

If you see "No modified Dart files detected." and expect there to be changes, check:

- That you're using the correct base branch with `-b`
- That you have uncommitted changes in your repository
- That the changes include Dart files
- That the file paths are correctly detected

Try running with `--verbose` to see more detailed output.

### Error: Not a git repository

The command must be run from within a Git repository. Change to the root directory of your project.

### Command execution fails

If your command fails to execute:

1. Try running the command directly without dart_diff to see if it works
2. Verify that the command is available in your environment
3. Run with the `--verbose` flag to see detailed logs
4. Check if the specified branch exists and is accessible

## Contributing

Contributions are welcome and appreciated! Here's how you can contribute:

- **Report bugs**: Open an issue describing the bug and how to reproduce it
- **Suggest features**: Open an issue describing your idea and its benefits
- **Submit PRs**: Implement bug fixes or features (please open an issue first)
- **Improve docs**: Fix typos, clarify explanations, add examples

Before opening a PR, run `dart test` and `bash tool/coverage.sh` in `packages/dart_diff_cli`. The coverage script fails unless every line under `lib/` is covered.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

Originally created by [Ajay Kumar] & [Dipangshu Roy].

Special thanks to all contributors who have helped improve this project.

<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action" alt="contributors"/>
  </a>
</div>

[Ajay Kumar]: https://github.com/ProjectAJ14
[Dipangshu Roy]: https://github.com/droyder7