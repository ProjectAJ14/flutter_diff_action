<p align="center">
  <h1 align="center">Flutter Diff Action</h1>
  <p align="center">Run Flutter/Dart commands on changed files with intelligence</p>
</p>

<p align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/releases"><img src="https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action?style=for-the-badge&logo=github&color=blue" alt="GitHub Release"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT"></a>
</p>

This project optimizes Flutter/Dart development workflows by running commands only on changed files, significantly speeding up CI/CD pipelines and local development.

## Table of Contents

- [Overview](#overview)
- [Project Components](#project-components)
- [GitHub Action](#github-action)
- [How It Works](#how-it-works)
- [Contributing](#contributing)

## Overview

Flutter Diff Action provides tools to make your development and CI workflows more efficient by focusing on what's changed:

- ⚡ **Faster workflows**: Run commands only on files that have changed
- 🧪 **Smarter testing**: Automatically find and run corresponding test files
- 📦 **Mono-repo friendly**: Full support for Melos-based workspaces
- 🛠️ **Flexible**: Works with testing, analysis, and formatting commands

## Project Components

This repository contains two complementary tools:

1. **GitHub Action**: For CI/CD pipelines to efficiently run commands on changed files
2. **Dart CLI Tool**: For local development to speed up testing and analysis workflows

Both tools intelligently identify changes, run commands only on affected files, and support mono-repo setups.

## GitHub Action

The GitHub Action component lets you run Flutter commands only on changed files in your CI/CD workflows.

### Requirements

- Flutter 3.27.0 or newer (Dart 3.6 or newer). CI tests the Action on Flutter 3.27.0 and the latest stable.
- A checkout with enough history to find the merge base with the base branch, e.g. `fetch-depth: 0`.
  With a shallow clone the Action falls back to diffing against the tip of the base branch.
- For `use-melos: true`, Melos must be installed and bootstrapped before the Action runs.

### Setup

```yaml
steps:
  - uses: actions/checkout@v5
    with:
      fetch-depth: 0
  - uses: subosito/flutter-action@v2

  - name: Run on changed files
    uses: ProjectAJ14/flutter_diff_action@v2
    with:
      command: 'flutter test'
      branch: ${{ github.base_ref }}
```

### Configuration Options

| Parameter     | Description                         | Required | Default   |
|---------------|-------------------------------------|----------|-----------|
| `command`     | Command to execute on changed files | Yes      | -         |
| `use-melos`   | Enable Melos support for mono-repos | No       | `false`   |
| `working-dir` | Working directory for the command   | No       | `.`       |
| `branch`      | Base branch for comparison          | No       | `main`    |
| `remote`      | Remote repository name              | No       | `origin`  |
| `debug`       | Show verbose output (`dart_diff --verbose`) | No       | `false`   |

### Examples

#### Basic Test Workflow

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test'
```

#### With Analysis

```yaml
- name: Analyze & test changed files
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter analyze'
    debug: true
```

#### For Mono-Repos

```yaml
- name: Setup Melos
  run: dart pub global activate melos

- name: Test changed packages
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test'
    use-melos: true
```

#### With Custom Base Branch

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test'
    branch: 'develop'
```

#### With Custom Remote

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test'
    remote: 'upstream'
```

## Common Workflows

### CI/CD Pipeline

```yaml
name: Flutter CI

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'

      - name: Setup Melos
        run: |
          dart pub global activate melos
          melos bootstrap

      - name: Run Tests
        uses: ProjectAJ14/flutter_diff_action@v2
        with:
          command: 'flutter test --no-pub --coverage'
          branch: ${{ github.base_ref }}
          use-melos: true
          debug: true
```

## How It Works

1. Installs the `dart_diff` CLI from the Action's own checkout, so `@v2` (or any tag or SHA) always runs the CLI code of that same tag. Nothing is downloaded from pub.dev.
2. Finds the files changed against the merge base with `<remote>/<branch>`, plus untracked files. Paths are limited to `working-dir`.
3. Keeps the Dart files and runs the command on them. Long file lists are split over several runs to stay under the OS command-line limit; the Action fails if any run fails. A test command that would need several runs runs the full suite once instead, so coverage and the summary stay whole.
4. For test commands (`flutter test`, `dart test`, `fvm flutter test`), each changed file is mapped to its test (`lib/a.dart` -> `test/a_test.dart`). The **full** test suite runs instead when a change can't be mapped to a test:
   - `pubspec.yaml`, `pubspec.lock`, `dart_test.yaml`, `build.yaml` or `l10n.yaml` changed,
   - a non-test file under `test/` changed (helpers, fixtures, goldens),
   - a non-Dart file under `lib/` or `assets/` changed,
   - a Dart file outside `test/` was deleted or renamed.

   Changed files with no matching test file are skipped.
5. The command's exit code is the step's exit code.

With `use-melos: true` the Action runs `git fetch` once, then `melos exec --diff=<remote>/<branch>` runs `dart_diff exec --no-fetch` in each changed package.

Inputs are passed to the scripts through environment variables, never pasted into them. `branch` and `remote` may only contain `A-Za-z0-9._/@+-` and can't start with `-`. `command` keeps shell quoting (e.g. `flutter test --plain-name "login flow"`), since it is your own workflow's input; don't build it from untrusted text such as PR titles.

## Contributing

Contributions are welcome and appreciated! Here's how you can contribute:

- **Report bugs**: Open an issue describing the bug and how to reproduce it
- **Suggest features**: Open an issue describing your idea and its benefits
- **Submit PRs**: Implement bug fixes or features (please open an issue first)
- **Improve docs**: Fix typos, clarify explanations, add examples

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