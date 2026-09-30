<p align="center">
  <a href="https://pub.dev/packages/dart_diff_cli">
    <img src="https://github.com/user-attachments/assets/2f925259-f0e2-448e-937e-22331f916d89" alt="Nonstop Logo" height="252" />
  </a>
  <p align="center">Runs Dart/Flutter tests, analysis and formatting only for what a change affects.</p>
</p>

[![dart_diff_cli](https://img.shields.io/pub/v/dart_diff_cli.svg?label=dart_diff_cli&logo=dart&color=blue&style=for-the-badge)](https://pub.dev/packages/dart_diff_cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A command-line interface for running Flutter and Dart commands efficiently on changed files.

## Table of Contents

- [Overview](#overview)
- [Commands](#commands)
  - [exec](#exec)
  - [report](#report)
  - [update](#update)
- [Common Workflows](#common-workflows)
- [Global Options](#global-options)
- [Troubleshooting](#troubleshooting)

## Overview

`dart_diff` runs a command only for what changed compared with a base branch or commit: the tests that use the changed code, the packages it reaches, or the changed files.

Key features include:
- Running every test that imports a changed file, directly or not, across local packages
- Running `analyze` in a package only when it, or something it uses, changed
- Supporting single packages, pub workspaces and Melos mono-repos
- Recording each run for a summary (`report`), e.g. as GitHub Actions outputs



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

| Option             | Alias | Description                                              | Default  |
|--------------------|-------|----------------------------------------------------------|----------|
| `--branch`         | `-b`  | Base branch for comparison                               | `main`   |
| `--remote`         | `-r`  | Remote repository name                                   | `origin` |
| `--base`           |       | Commit or ref to compare with, instead of `<remote>/<branch>` | -   |
| `--[no-]fetch`     |       | Run `git fetch` for the base first                       | on       |
| `--mode`           |       | `auto`, `test`, `files` or `package` (see below)         | `auto`   |
| `--all`            |       | Run on everything, without looking at the changes        | off      |
| `--run-all-on`     |       | Glob, relative to the repository root; a changed file matching it runs everything. Repeatable. | - |
| `--report`         |       | Directory to write a JSON file about this run into (see [report](#report)) | - |
| `--dry-run`        |       | Work out what would run without running it; the command is optional | off |

`--branch`, `--remote` and `--base` can't start with `-`.

**What changed:** the files in `git diff <merge base>` plus untracked files, across the whole repository, where the merge base is that of `<remote>/<branch>` (or `--base`) and `HEAD`. The current directory must contain a `pubspec.yaml`.

- A failed `git fetch` only prints a warning and uses the local ref. Use `--no-fetch` when the ref is already up to date, e.g. after fetching once for every package of a mono-repo.
- In a shallow clone with no merge base, 100 and then 1000 more commits are fetched. With still no merge base, it warns and diffs against the base itself, which also counts what changed on the base.
- When `HEAD` is already part of the base (e.g. on `main` itself), it warns that only uncommitted changes count.

**What runs**, by mode. `auto` picks `test` for `flutter test`, `dart test` and `fvm flutter test`, `package` for `flutter analyze` and `dart analyze` (and when there is no command), `files` otherwise.

- `test`: the command gets every `test/**_test.dart` that imports, exports or includes as a `part` a changed file, directly or through other files, plus the changed test files themselves. `package:` imports are followed into local packages (workspace members, path dependencies) with `.dart_tool/package_config.json`, so a test is picked when a package it uses changed. Without a package config, only this package's own `package:` imports are followed. A deleted file's importers are picked the same way. The command runs with no files (the whole suite) when:
  - `pubspec.yaml`, `pubspec.lock`, `pubspec_overrides.yaml`, `dart_test.yaml`, `build.yaml` or `l10n.yaml` changed,
  - `pubspec.yaml`, `pubspec.lock`, `pubspec_overrides.yaml`, `melos.yaml` or `analysis_options.yaml` changed in a parent directory (the workspace root),
  - `flutter_test_config.dart` changed, or a non-Dart file under `test/`, `lib/` or `assets/` (fixtures, goldens, l10n),
  - a changed file matches `--run-all-on`, or `--all` is passed,
  - the tests would need more than one command line (see below).

  If no test uses the changes, nothing runs.
- `package`: the command runs with no files when a file of the package changed, a file it imports from another local package changed, or the workspace config above changed. Otherwise nothing runs. Use it for `analyze`, whose errors can be in the files using a changed one.
- `files`: the command gets the changed Dart files of the package (all of them with `--all` or a `--run-all-on` match).

**Long file lists:** the files are split over several runs of the command so each command line stays under the OS limit (6000 characters on Windows, leaving room for what `flutter.bat` adds to cmd.exe's 8191 limit). Every run happens, even after a failure. A test command that would need several runs runs the full suite once instead, so coverage and the test summary stay whole.

`exec` stops reading its own options at the first word of the command, so `--` is optional: `dart_diff exec -b develop flutter test --coverage` works too.

When the `GITHUB_ACTIONS` environment variable is `true`, warnings are printed as GitHub Actions annotations.

**Exit codes:**

| Code | Meaning |
|------|---------|
| `0`  | The command succeeded, or there was nothing to run |
| `1`  | No `pubspec.yaml`, no command given, not a git repository, an unknown base, or the diff failed |
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

**Run the analyzer when the package is affected**

```bash
# Analyze the whole package if it, or a package it uses, changed
dart_diff exec -- dart analyze --fatal-infos
```

**Compare with the commit before a push**

```bash
dart_diff exec --base "$BEFORE_SHA" -- flutter test
```

**Format changed files**

```bash
# Format changed files
dart_diff exec -- dart format

# Format with specific options
dart_diff exec -- dart format --set-exit-if-changed
```

### report

Sums up the runs that `exec --report <dir>` recorded (one per package in a mono-repo) as GitHub Actions outputs and a Markdown summary. The GitHub Action runs it after `exec`.

```bash
dart_diff report [--output <file>] [--summary <file>] <dir>
```

| Option      | Description |
|-------------|-------------|
| `--output`  | Append `key=value` outputs to this file, e.g. `$GITHUB_OUTPUT`: `ran` (`none`/`partial`/`full`), `full-suite`, `skipped`, and the JSON arrays `changed-files`, `files`, `test-files` and `packages` |
| `--summary` | Append a Markdown summary to this file, e.g. `$GITHUB_STEP_SUMMARY` |

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

# Analyze, if anything the package uses changed
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

### Nothing to run

If you see "Nothing to run: ..." and expect there to be changes, check:

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